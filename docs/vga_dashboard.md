# Dashboard VGA do ACES — DE10-Lite

## Arquitetura

O dashboard é um consumidor isolado da telemetria do ACES. Ele não acessa as
RAMs internas do FFT/analisador e não gera backpressure no pipeline de áudio.
A primeira versão usa renderização procedural, sem framebuffer RGB completo.

```text
50 MHz / ACES DSP → dashboard_data_capture → toggle CDC → 25 MHz / VGA
                                      → vga_timing → dashboard_renderer
                                      → VGA R/G/B + HS/VS
```

## Clock e timing

`vga_pixel_clock_div2.sv` gera 25 MHz por divisão síncrona do clock de 50 MHz.
Esta escolha é reproduzível em Quartus sem depender de IP binário de PLL. É
ligeiramente diferente dos 25,175 MHz nominais, mas mantém o formato 640×480
para o bring-up inicial. A restrição `VGA_PIXEL_CLK` descreve o clock dividido.

| Campo | Horizontal | Vertical |
|---|---:|---:|
| Ativo | 640 | 480 |
| Front porch | 16 | 10 |
| Sync | 96 | 2 |
| Back porch | 48 | 33 |
| Total | 800 | 525 |

HSYNC e VSYNC são ativos em nível baixo. RGB é zero durante o blanking e as
saídas RGB são registradas no domínio de pixel clock.

## Pinout VGA

As atribuições foram conferidas contra o SystemCD da DE10-Lite e usam
`3.3-V LVTTL`:

| Sinal | Pino | Sinal | Pino |
|---|---|---|---|
| VGA_HS | N3 | VGA_VS | N1 |
| VGA_R[0..3] | AA1, V1, Y2, Y1 | VGA_G[0..3] | W1, T2, R2, R1 |
| VGA_B[0..3] | P1, T1, P4, N2 | | |

## Captura e double buffer

No domínio de 50 MHz, cada bin útil (`fft_tx_index < 512`) é armazenado com
24 bits após a métrica de magnitude de amplitude:

```text
raw_magnitude = saturate((abs(real) + abs(imag)) << bfpexp)
```

O pico do quadro é armazenado junto com o snapshot. Durante a leitura no
domínio VGA, a magnitude é normalizada por uma potência de dois derivada desse
pico, sem divisor no caminho de pixel. Assim, um `bfpexp` alto não transforma
todos os bins em `MAX`; o pico fica próximo do topo e os demais bins preservam
sua relação relativa. Não há `sqrt` no caminho de vídeo. Os 512 bins e 13 MFCC Q16.16 ficam em dois
bancos. O banco de escrita é separado do banco exibido. `feature_frame_done`
marca o snapshot, um toggle atravessa dois flip-flops e o VGA só aceita o banco
novo em `frame_start`, evitando tearing.

```text
50 MHz: escrever banco A ─ frame_done ─ toggle ─┐
                                                ├─ 25 MHz: frame_start → swap
25 MHz: consumir banco B ◄─────────────────────┘
```

O captura nunca espera o VGA e não desabilita os eventos do DSP. Barramentos
multibit não são sincronizados bit a bit; eles só são lidos após o banco estar
estável e o toggle ter sido sincronizado.

## Layout e renderização

### Fronteira do frame para MFCC

O leitor DMA da FFT percorre os 1024 bins e sinaliza `fft_tx_last` no bin
1023. O analisador de características processa somente os 512 bins úteis
(`0..511`). Por isso o top-level gera `feature_bin_last` no bin 511 e o usa
exclusivamente na entrada do analisador MFCC. Sem essa adaptação, as etapas
Mel/log/DCT não eram iniciadas e `feature_frame_done` permanecia em zero,
impedindo a atualização de MFCC e do contador de frames do dashboard.

- espectro: x=64..575, y=72..280, com escala de frequência logarítmica;
- MFCC: x=60..319, centro em y=405, barras assinadas;
- status: indicadores em x=430..449;
- eixo X: aproximadamente 50 Hz, 500 Hz, 4 kHz, 12 kHz e 24 kHz;
- eixo Y: magnitude de amplitude relativa em dB (`0`, `-15`, `-30`, `-45`, `-60 dB`).
  O valor de referência é o maior pico mantido pelo `peak_hold`; portanto a
  escala é dB relativa ao pico observado, não dB SPL calibrado.
- indicadores de status identificados como `RUN`, `BUSY`, `DONE` e `ERR`, além de
  `FRAME` e `BFP`;
- fonte procedural 8×8 em `font_rom.sv`;
- fundo preto, grade discreta, FFT ciano, MFCC amarelo, estados verde/vermelho.

O mapeamento X usa `spectrum_log_lut.sv`: os 512 pixels do gráfico consultam
64 entradas, com interpolação linear entre as entradas para cada um dos oito
pixels do segmento. A LUT percorre os bins 1..511 em progressão aproximadamente logarítmica. Assim, as baixas frequências ocupam
mais espaço visual, sem calcular logaritmos ou divisões no caminho de pixel.
O bin 0/DC não é exibido como ponto separado; a primeira posição representa o
bin 1, equivalente a 46,875 Hz em `Fs=48 kHz` e `N=1024`.

## Pré-processamento de áudio

O caminho de análise inclui `rtl/frontend/audio_dc_blocker.sv` entre o CDC das
amostras I2S e o buffer de overlap. Ele implementa um passa-altas IIR de primeira
ordem:

```text
y[n] = x[n] - x[n-1] + alpha*y[n-1]
alpha = 65109 / 65536
```

Para `Fs=48 kHz`, o coeficiente corresponde a uma frequência de corte de
aproximadamente 50 Hz. O mesmo sinal filtrado alimenta a janela Hann, a FFT e o
MFCC. Isso remove offset DC, deriva lenta e parte do ruído de 50/60 Hz sem
alterar significativamente sinais na faixa de kHz.

## Escala vertical e peak hold

O espectro visual não é mais normalizado pelo pico de cada frame. O módulo de
captura mantém `peak_hold`, que só aumenta quando um novo frame apresenta uma
magnitude maior que o máximo histórico. O valor é mantido até o reset `KEY0`.
Assim, a referência permanece comparável entre frames. A captura publica a
potência de cada frame sem média temporal, preservando a inferência dos bancos
como RAM dual-clock e o timing do projeto. A média temporal será adicionada em
uma etapa posterior com RAM multiporta explícita; uma leitura variável do banco
anterior dentro do mesmo processo faz o Quartus expandir a memória em uma
matriz combinacional muito grande. O renderer converte a potência normalizada
para dB relativo e desenha uma linha de dois pixels, em vez de barras
preenchidas.

## Módulos

```text
rtl/video/vga_pixel_clock_div2.sv
rtl/video/vga_timing.sv
rtl/video/font_rom.sv
rtl/video/text_renderer.sv
rtl/video/dashboard_data_capture.sv
rtl/video/dashboard_renderer.sv
```

O top-level preserva I2S, FFT, MFCC, LEDs, HEX e GPIOs, adicionando os cinco
sinais VGA.

## Verificação

`tb/unit/tb_vga_timing.sv` verifica um quadro completo: 307.200 pixels ativos,
50.400 clocks com HSYNC baixo e exatamente um `frame_start` em 800×525 clocks.

```bash
iverilog -g2012 -s tb_vga_timing -o /tmp/tb_vga_timing.vvp \
  rtl/video/vga_timing.sv tb/unit/tb_vga_timing.sv
vvp /tmp/tb_vga_timing.vvp
```

Também existe um smoke test visual sintético, independente do RTL:

```bash
python sim/vga_dashboard_ppm.py
```

Ele gera `simulation_output/dashboard_frame.ppm` para inspeção rápida do
layout, escala do espectro e barras MFCC.

## Fechamento Quartus/TimeQuest

No fechamento físico realizado em 2026-09-12, o Fitter foi bem-sucedido para
`10M50DAF484C7G`, com 10.914 células lógicas, 459 segmentos RAM, 40 DSPs e
48 pinos de entrada/saída implementados. Os bancos de espectro de 24 bits são
inferidos como RAM dual-clock. O TimeQuest encontrou clocks de 50 MHz,
3,125 MHz I2S e 25 MHz VGA; hold permaneceu positivo. O pior setup no corner
lento de 85 °C foi `-0,611 ns` no clock principal, enquanto o VGA passou com
`5,284 ns`. Portanto, o bitstream é gerado e o dashboard passa a validação
funcional, mas o pequeno déficit do clock principal ainda deve ser fechado
antes de classificar o bitstream como produção.

## Limitações e extensões

O clock atual é 25 MHz; o valor FFT é magnitude relativa em dB, não dB SPL;
waveform e waterfall ainda não fazem parte da primeira versão. No fechamento
atual, os bancos de snapshot são inferidos como RAM dual-clock. A média
temporal ainda não está habilitada: uma implementação ingênua com leitura do
banco anterior expandiu a RAM para lógica e falhou o limite de recursos; ela
deve ser feita em RAM multiporta explícita em uma etapa posterior.
Como extensões, podem ser adicionados waveform circular, escala dB calibrada,
waterfall e PLL próximo de 25,175 MHz sem alterar o contrato de telemetria.
