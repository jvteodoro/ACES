# Relatório de recursos para dashboard VGA

## 1. Objetivo

Este documento reúne os recursos disponíveis no projeto ACES para orientar a
especificação de um dashboard gráfico na saída VGA da DE10-Lite. Ele descreve
o que já existe, o que pode ser reutilizado e quais interfaces ainda precisarão
ser criadas no RTL.

Conclusão principal: a placa possui saída VGA nativa de 4 bits por canal, mas
o top-level atual ainda não possui sinais VGA nem controlador de vídeo. O
dashboard deve ser implementado como um novo domínio de vídeo, alimentado por
um banco de snapshots do processamento de áudio. Não é recomendável que o
renderizador VGA leia diretamente as RAMs internas do MFCC enquanto elas estão
sendo atualizadas.

## 2. Dispositivo e recursos físicos

Projeto Quartus: `quartus/de10lite_audio_fft.qpf`  
Top-level: `rtl/top/de10lite_audio_fft_top.sv`  
Dispositivo: `10M50DAF484C7G`  
Família: MAX 10  
Clock da placa: `MAX10_CLK1_50`, 50 MHz, pino `P11`.

Uso medido no último fit do projeto atual:

| Recurso | Uso | Disponível | Percentual |
|---|---:|---:|---:|
| Logic elements | 7.417 | 49.760 | 15% |
| Funções combinacionais | 6.655 | 49.760 | 13% |
| Registradores | 2.430 | 51.509 | 5% |
| M9K | 23 | 182 | 13% |
| Memória embarcada | 166.966 bits | 1.677.312 bits | 10% |
| Elementos multiplicadores de 9 bits | 38 | 288 | 13% |
| Pinos usados | 83 | 360 | 23% |

Há margem relevante de lógica, RAM e multiplicadores para um controlador VGA
procedural, geradores de gráficos, filtros de escala e pequenos buffers. O
recurso mais limitante para um dashboard é memória de frame completa, não a
lógica.

## 3. Saída VGA disponível na DE10-Lite

O SystemCD local da placa (`C:\Users\jvcte\DE10Lite`) define a seguinte
interface VGA. Todos os sinais usam `3.3-V LVTTL`:

| Sinal | Pino MAX 10 |
|---|---|
| `VGA_HS` | `N3` |
| `VGA_VS` | `N1` |
| `VGA_R[3:0]` | `AA1`, `V1`, `Y2`, `Y1` |
| `VGA_G[3:0]` | `W1`, `T2`, `R2`, `R1` |
| `VGA_B[3:0]` | `P1`, `T1`, `P4`, `N2` |

A ordem dos bits é `[0]` no primeiro pino listado de cada canal. A saída
fornece 12 bits de cor, ou 4096 cores possíveis, assumindo a rede analógica
VGA da placa.

Esses sinais aparecem no `DE10_LITE_Golden_Top.qsf` do SystemCD, mas ainda não
estão atribuídos em `quartus/de10lite_audio_fft.qsf`. A implementação do
dashboard deverá adicionar os ports VGA ao top-level, as atribuições de pinos
ao QSF e o padrão de I/O `3.3-V LVTTL`.

## 4. Temporização VGA recomendada

Para o primeiro dashboard, o modo recomendado é `640x480 @ 60 Hz`:

| Parâmetro | Valor |
|---|---:|
| Área ativa | 640 × 480 |
| Total horizontal | 800 pixels |
| Total vertical | 525 linhas |
| Pixel clock nominal | 25,175 MHz |
| HSync | 96 pixels |
| Back porch horizontal | 48 pixels |
| Front porch horizontal | 16 pixels |
| VSync | 2 linhas |
| Back porch vertical | 33 linhas |
| Front porch vertical | 10 linhas |

O projeto já possui um clock de 50 MHz, portanto é possível iniciar com um
pixel clock de 25 MHz por divisão inteira. Para compatibilidade rigorosa com o
VGA, deve-se criar um PLL/IP para 25,175 MHz. O clock de pixel precisa ser
declarado no SDC e todos os sinais `VGA_*` devem ser registrados nesse domínio.

O sinal de sincronismo VGA normalmente é ativo em nível baixo para este modo.
O prompt de implementação deve exigir contadores horizontais e verticais,
blanking explícito e cor preta fora da área ativa.

## 5. Memória e arquitetura de framebuffer

Uma imagem completa de 640×480 usando 12 bits por pixel exigiria:

```text
640 × 480 × 12 = 3.686.400 bits
```

Isso excede os 1.677.312 bits de memória embarcada do MAX 10. Mesmo uma
imagem de 8 bits por pixel exigiria 2.457.600 bits. Portanto, as opções são:

1. renderização procedural direta, sem framebuffer;
2. dois line buffers de 640 pixels;
3. framebuffer reduzido de 320×240 com 12 bits por pixel, exibido com
   duplicação 2×2;
4. framebuffer externo, caso um hardware de memória adicional seja incluído.

Para um dashboard de espectro, a opção 1 ou 2 é a mais adequada. Barras,
linhas, textos e marcadores podem ser gerados diretamente a partir de RAMs de
dados compactas. Um framebuffer 320×240×12 usa aproximadamente 921.600 bits,
mas consumiria cerca de 52 M9Ks, além das 23 M9Ks já utilizadas.

## 6. Dados de áudio disponíveis

O caminho atual é:

```text
I2S -> amostras 24 bits -> truncamento para 18 bits -> janela Hann
    -> FFT R2FFT de 1024 pontos -> leitura DMA dos bins
    -> potência -> 32 bandas Mel -> log -> 13 MFCC
    -> estabilizador temporal EMA
```

Parâmetros atuais do top-level:

| Dado | Configuração |
|---|---|
| Clock de sistema | 50 MHz |
| Taxa de áudio nominal | 48 kHz |
| FFT | 1024 pontos |
| Hop | 512 amostras, 50% |
| Janela | Hann habilitada |
| Dados FFT | real e imaginário, 18 bits assinados |
| Expoente | BFP, 8 bits assinados |
| Bins processados | `FFT_LENGTH/2 = 512` bins |
| Bandas Mel | 32 |
| Coeficientes MFCC | 13 |
| Formato MFCC | signed Q16.16 |
| Estabilização | EMA com `alpha = 1/4` |

O cálculo do analisador usa RAMs internas para potência, energia Mel, log e
ROMs para coeficientes. Entretanto, essas estruturas são internas ao módulo
`fft_feature_analyzer`; o top-level atualmente só recebe os resultados MFCC
um por vez.

## 7. Sinais atualmente acessíveis no top-level

O top-level já possui sinais que podem ser conectados a uma interface de
telemetria para o dashboard:

| Sinal interno | Largura | Uso possível |
|---|---:|---|
| `sample_mic` | 18 bits | forma de onda temporal |
| `fft_sample` | 18 bits | amostra enviada à FFT |
| `istream_real/imag` | 18 bits cada | stream de entrada do FFT |
| `fft_tx_real/imag` | 18 bits cada | bins pós-FFT |
| `fft_tx_index` | 10 bits | índice do bin |
| `fft_tx_valid` | 1 | bin válido |
| `fft_tx_last` | 1 | último bin do frame |
| `bfpexp` | 8 bits | escala BFP |
| `fft_run` | 1 | FFT em execução |
| `fft_done` | 1 | FFT concluída |
| `fft_status` | 3 bits | estado da FFT |
| `fft_input_status` | 2 bits | estado dos buffers de entrada |
| `feature_busy` | 1 | MFCC ocupado |
| `mfcc_index` | 4 bits | índice 0..12 |
| `mfcc_data` | 32 bits | MFCC estabilizado Q16.16 |
| `mfcc_valid` | 1 | MFCC válido |
| `feature_frame_done` | 1 | frame MFCC concluído |

No entanto, `sample_mic`, os bins FFT e os dados intermediários não são
armazenados para leitura posterior pelo vídeo. Um módulo de dashboard precisa
adicionar uma das seguintes interfaces:

* captura do bin atual em registradores de snapshot;
* RAM dual-port para espectro e forma de onda;
* FIFO de frames para o domínio VGA;
* banco de 32 energias Mel e 13 MFCC atualizado no fim de cada frame.

## 8. Sinais já usados pela placa

O top-level atual utiliza:

* `GPIO[0]`: entrada serial I2S do microfone;
* `GPIO[1..3]`: SCK, WS e seleção L/R do microfone;
* `GPIO[4..6]`: saída I2S FFT opcional;
* `GPIO[7]`: `mfcc_valid`;
* `GPIO[8]`: `feature_frame_done`;
* `GPIO[9..35]`: alta impedância e reservados;
* `SW[0]`: seleção do canal L/R;
* `KEY[0]`: reset ativo baixo;
* `LEDR[0..9]`: estado do pipeline;
* `HEX0..HEX2`: índice e nibbles baixos do MFCC atual.

Os GPIOs não devem ser usados pelo VGA, porque a DE10-Lite possui o conector
VGA dedicado. GPIOs livres podem ser reservados para debug, seleção de página
ou medição com osciloscópio.

## 9. Arquitetura de dados recomendada para o dashboard

O prompt de implementação deve especificar um `dashboard_data_capture` no
clock de 50 MHz, separado do `vga_controller` no clock de pixel:

```text
fft_tx stream / MFCC result
        |
        +--> snapshot de bins ou RAM espectral
        +--> acumulador Mel de leitura
        +--> banco MFCC estabilizado
        +--> contadores/status
                    |
             CDC seguro para VGA
                    |
          VGA timing + renderer + texto
```

Recomendação de conteúdo de uma tela inicial:

* barras das 32 bandas Mel;
* gráfico dos 13 MFCC;
* espectro dos 512 bins em resolução reduzida;
* forma de onda temporal de 512 ou 1024 amostras;
* indicadores de `FFT run`, `FFT done`, `feature_busy` e `frame_done`;
* expoente BFP e taxa de frames;
* indicador de saturação/clipping e nível de ruído, se esses dados forem
  adicionados ao analisador.

Para evitar disputa de acesso e tearing, o dashboard deve trocar dados apenas
quando `feature_frame_done` for observado. O banco de dados deve usar double
buffer, handshake de frame ou uma RAM dual-port com índice de frame.

## 10. Recursos que ainda precisam ser implementados

O projeto atual não possui:

* ports `VGA_R`, `VGA_G`, `VGA_B`, `VGA_HS`, `VGA_VS`;
* controlador de sincronismo VGA;
* pixel clock dedicado ou PLL;
* fonte de caracteres/font ROM;
* renderer de barras, linhas ou texto;
* captura persistente de bins, Mel ou forma de onda;
* CDC formal entre o domínio de áudio e o domínio VGA;
* testbench de timing e conteúdo da imagem VGA;
* restrições SDC para o clock de pixel e saídas VGA.

## 11. Requisitos que o prompt de implementação deve conter

O prompt deve exigir explicitamente:

1. compatibilidade com `10M50DAF484C7G` e Quartus Prime 25.1;
2. modo VGA escolhido, preferencialmente 640×480@60 Hz;
3. pixel clock de 25 MHz dividido ou 25,175 MHz via PLL;
4. sinais registrados e sincronismos com polaridade documentada;
5. uso de RAM compatível com os recursos M9K disponíveis;
6. nenhuma framebuffer completa de 640×480×12 bits dentro da FPGA;
7. captura coerente dos dados no evento `feature_frame_done`;
8. tratamento do signed Q16.16 dos MFCC;
9. escala log/linear documentada para espectro e Mel;
10. saturação de cores e valores fora da área ativa;
11. testbench que verifique contadores VGA, pulsos HS/VS, blanking, barras e
    atualização de frame;
12. recompilação Quartus, análise de timing e simulação Questa antes do merge;
13. atualização do QSF, SDC, top-level, pinout e documentação;
14. preservação dos sinais I2S e do processamento de áudio existentes.

## 12. Fontes consultadas

* `rtl/top/de10lite_audio_fft_top.sv`
* `rtl/core/aces.sv`
* `rtl/analysis/fft_feature_analyzer.sv`
* `rtl/analysis/feature_temporal_stabilizer.sv`
* `quartus/de10lite_audio_fft.qsf`
* `quartus/de10lite_audio_fft.sdc`
* `quartus/output_files_de10lite/de10lite_audio_fft.fit.rpt`
* `docs/de10lite_pinout.md`
* `docs/fpga_feature_analyzer.md`
* `docs/feature_numeric_spec.md`
* `C:\Users\jvcte\DE10Lite\DE10_LITE_Golden_Top.qsf`
