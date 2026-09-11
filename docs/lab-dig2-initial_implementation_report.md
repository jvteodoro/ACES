# Relatório técnico da branch `lab-dig2-initial`

## 1. Objetivo

Esta branch migra o caminho de análise de áudio que anteriormente dependia do Raspberry Pi para processamento local na FPGA DE10-Lite. O objetivo principal foi eliminar a transmissão dos bins da FFT para um processador externo e executar, dentro do MAX 10, o fluxo necessário para produzir características MFCC:

```text
microfone I2S
    -> captura de amostras
    -> conversão 24 bits para 18 bits
    -> janela de Hann
    -> enquadramento com sobreposição
    -> FFT de 1024 pontos
    -> leitura DMA dos bins
    -> potência espectral
    -> banco Mel
    -> logaritmo
    -> DCT-II ortonormal
    -> estabilização temporal
    -> MFCC Q16.16
```

A motivação da mudança foi retirar as limitações introduzidas pelo canal FPGA–Raspberry Pi: largura limitada, serialização, necessidade de sincronização externa, tráfego de todos os bins e processamento parcial fora da FPGA.

## 2. Estado da branch

Branch atual:

```text
lab-dig2-initial
```

Commit principal desta etapa:

```text
f9bff5e feat: remove legacy FFT host transport
```

Commits funcionais acumulados na branch:

| Commit | Conteúdo |
|---|---|
| `2c8c118` | Primeiro analisador Mel/MFCC na FPGA |
| `ae3652e` | Migração do caminho de áudio para DE10-Lite |
| `3ddac1e` | Referência numérica e testes das características |
| `8e41467` | Clock de áudio fracionário e janela de Hann |
| `006114d` | FFT de 1024 pontos com enquadramento sobreposto |
| `b053f33` | Maior precisão no cálculo espectral |
| `ba42abd` | ROMs de características e suavização temporal |
| `f9bff5e` | Remoção do transporte FFT legado para o host |

O commit foi publicado em `origin/lab-dig2-initial`.

## 3. Arquitetura final

### 3.1. Top-level da DE10-Lite

O top-level é `rtl/top/de10lite_audio_fft_top.sv`. Ele usa o clock de 50 MHz da placa e integra:

- interface física do microfone I2S;
- pipeline de aquisição e enquadramento;
- núcleo R2FFT existente;
- leitor DMA dos resultados da FFT;
- analisador Mel/MFCC;
- estabilizador temporal;
- LEDs, displays de sete segmentos e GPIOs de diagnóstico.

O reset é derivado de `KEY[0]`:

```systemverilog
assign rst = ~KEY[0];
```

O switch `SW[0]` seleciona o canal lógico L/R do microfone. A entrada de dados do microfone está em `GPIO[0]`.

### 3.2. Mapeamento dos GPIOs

| GPIO | Direção | Função |
|---:|:---:|---|
| 0 | entrada | Serial data do microfone I2S |
| 1 | saída | SCK gerado para o microfone |
| 2 | saída | WS/LRCLK gerado para o microfone |
| 3 | saída | Seleção L/R do microfone |
| 4 | saída | Reservado; transporte FFT legado desabilitado |
| 5 | saída | Reservado; transporte FFT legado desabilitado |
| 6 | saída | Reservado; transporte FFT legado desabilitado |
| 7 | saída | `mfcc_valid` |
| 8 | saída | `frame_done` |
| 9–35 | alta impedância | Expansão não utilizada durante o bring-up |

Os GPIOs 4–6 continuam presentes na interface externa para reduzir incompatibilidades com versões anteriores do top-level, mas não representam mais um canal de dados funcional. O caminho de análise não depende deles.

### 3.3. Fluxo de controle

O processamento ocorre em dois ritmos diferentes:

1. O áudio é capturado continuamente na taxa do microfone.
2. A cada 512 novas amostras é formado um novo frame de 1024 amostras.
3. A FFT é executada sobre o frame.
4. Quando a FFT sinaliza `done`, o `fft_dma_reader` percorre os 1024 endereços.
5. O analisador armazena os bins úteis e inicia seu processamento sequencial.
6. Os 13 coeficientes MFCC são emitidos um por vez.
7. O estabilizador aplica EMA por coeficiente.
8. `frame_done` indica o fim do conjunto de coeficientes do frame.

O analisador reutiliza multiplicadores e um acumulador. Isso reduz a área de hardware e é adequado porque o intervalo entre frames de áudio é grande em relação aos aproximadamente milhares de ciclos necessários para o pós-processamento.

## 4. Migração para FFT de 1024 pontos

### 4.1. Resolução espectral

A configuração padrão da branch é:

| Parâmetro | Valor |
|---|---:|
| FFT | 1024 pontos |
| Taxa de amostragem | 48 kHz |
| Espaçamento espectral ideal | aproximadamente 46,875 Hz/bin |
| Hop | 512 amostras |
| Duração do frame | aproximadamente 21,33 ms |
| Avanço entre frames | aproximadamente 10,67 ms |
| Bins positivos usados pelo MFCC | 512 |
| Bandas Mel | 32 |
| Coeficientes MFCC emitidos | 13 |

Com 1024 pontos, a resolução espectral é aproximadamente metade da resolução de uma FFT de 512 pontos, mantendo um avanço temporal de 512 amostras.

### 4.2. Leitura completa dos bins

O módulo `rtl/common/fft_dma_reader.sv` recebeu o parâmetro:

```systemverilog
parameter int OUTPUT_BINS = FFT_LENGTH
```

Na configuração final, `OUTPUT_BINS=1024`. O leitor:

- detecta o pulso de conclusão da FFT;
- espera o número de ciclos definido por `READ_LATENCY`;
- gera o endereço DMA;
- captura real e imaginário;
- gera `fft_bin_valid_o`;
- marca o último bin com `fft_bin_last_o`.

O analisador recebe diretamente os 1024 resultados. Como o espectro de um sinal real é simétrico, ele armazena apenas os bins cujo índice é menor que `USEFUL_BINS=512`. Os bins restantes são consumidos pelo fluxo DMA, mas não são usados no banco Mel.

Essa decisão mantém a memória do banco Mel em 32 × 512 posições e evita duplicar informação espectral. Uma evolução futura pode incluir explicitamente o bin de Nyquist, usando 513 bins úteis e ROMs dimensionadas para essa quantidade.

## 5. Enquadramento com sobreposição

O módulo `rtl/frontend/audio_overlap_frame_buffer.sv` implementa um buffer circular em RAM.

Características:

- profundidade padrão: 1024 amostras;
- primeira saída após acumular 1024 amostras;
- nova saída a cada 512 amostras;
- leitura do frame em burst de uma amostra por ciclo;
- indicação de início e fim do burst;
- armazenamento inferido em memória embarcada.

O buffer possui ponteiros independentes de escrita e leitura. A escrita continua ocorrendo na taxa de áudio, enquanto a leitura do frame é feita em burst no clock do sistema. Como o processamento da FFT acontece entre os eventos de aquisição dos frames, não é necessário transmitir o frame por um canal externo ou interromper a aquisição.

O pipeline `rtl/core/aces_audio_to_fft_pipeline.sv` habilita:

```systemverilog
.ENABLE_OVERLAP(1'b1),
.HOP_LENGTH(FFT_LENGTH / 2),
.ENABLE_WINDOW(1'b1)
```

## 6. Janela de Hann

Foram adicionadas ROMs de coeficientes para a janela de Hann:

- `rtl/frontend/hann_window_q15.hex`;
- `rtl/frontend/hann_window_q15_1024.hex`.

Os coeficientes usam representação Q1.15. O módulo `rtl/frontend/fft_window_multiplier.sv` multiplica cada amostra por seu coeficiente e reduz o resultado para a largura do caminho da FFT.

Na configuração DE10-Lite é usada a ROM de 1024 pontos:

```systemverilog
.WINDOW_COEFF_FILE("../rtl/frontend/hann_window_q15_1024.hex")
```

A janela reduz leakage espectral e melhora a separação de componentes em ambiente ruidoso, especialmente quando a frequência do sinal não coincide exatamente com o centro de um bin.

## 7. Analisador espectral e MFCC

O módulo principal é `rtl/analysis/fft_feature_analyzer.sv`.

### 7.1. Máquina de estados

A implementação usa os estados:

```text
IDLE -> MEL_PREP -> MEL_ACC -> LOG_ACC -> DCT_ACC -> EMIT
```

#### `IDLE`

- recebe os bins da FFT;
- calcula a potência espectral;
- grava a potência na RAM;
- espera `fft_bin_last_i`.

#### `MEL_PREP`

- seleciona a banda Mel;
- inicializa o acumulador;
- define o primeiro bin da banda.

#### `MEL_ACC`

- multiplica potência pelo coeficiente Mel;
- acumula os produtos;
- grava a energia da banda quando a borda direita é alcançada.

#### `LOG_ACC`

- calcula o logaritmo natural da energia Mel;
- grava os 32 valores logarítmicos.

#### `DCT_ACC`

- multiplica os valores log-Mel pelos coeficientes DCT;
- acumula cada coeficiente;
- emite os 13 resultados MFCC.

#### `EMIT`

- encerra o processamento do frame;
- retorna ao estado ocioso para aceitar o próximo frame.

### 7.2. Potência espectral e block floating point

Para cada bin, a potência é calculada como:

```text
P[k] = Re[k]^2 + Im[k]^2
```

O núcleo FFT fornece um expoente de block floating point (`fft_bfpexp_i`). O analisador aplica aproximadamente:

```text
Pesc[k] = P[k] << (2 * bfpexp)
```

Quando o expoente é negativo, é realizada uma redução por deslocamento à direita. O resultado é saturado para a largura configurada de `POWER_W=48` bits.

Essa abordagem evita descartar a escala global produzida pela FFT e reduz a probabilidade de overflow durante a soma das energias Mel.

### 7.3. Memórias de potência e energia

As principais estruturas são:

| Estrutura | Dimensão | Largura | Uso |
|---|---:|---:|---|
| `power_ram` | 512 | 48 bits | Potência dos bins úteis |
| `mel_energy` | 32 | 48 bits | Energia de cada filtro Mel |
| `log_energy` | 32 | 32 bits | Logaritmo das energias Mel |
| `mel_coeff_rom` | 32 × 512 | 16 bits | Pesos dos filtros Mel |
| `log_mantissa_rom` | 256 | 32 bits | Aproximação logarítmica |

O código utiliza atributos `ramstyle`/`romstyle` para orientar o Quartus a mapear essas estruturas nas memórias embarcadas disponíveis no MAX 10.

### 7.4. Banco Mel

O arquivo `rtl/analysis/mel_coeffs_1024_q16.hex` contém os pesos dos 32 filtros Mel para os 512 bins positivos usados.

Os coeficientes são Q16:

```text
coeficiente_real = valor_inteiro / 65536
```

O banco usa filtros triangulares com normalização de área. A normalização evita que bandas com larguras diferentes tenham energia artificialmente maior apenas por possuírem mais bins.

O arquivo foi corrigido para conter palavras de 16 bits, eliminando a inconsistência anterior em que valores de 20 bits eram carregados em uma ROM de 17 bits.

O analisador ainda mantém uma função procedural `mel_weight` como fallback para testes ou configurações sem ROM. No top da DE10-Lite, a ROM está habilitada:

```systemverilog
.USE_MEL_ROM(1'b1)
```

### 7.5. Logaritmo

O logaritmo é obtido pela decomposição:

```text
x = 2^m × mantissa
ln(x) = m × ln(2) + ln(mantissa)
```

A mantissa normalizada está no intervalo `[1, 2)`. Os oito bits seguintes ao bit líder selecionam uma entrada de `log_mantissa_q16.hex`.

Para energia zero é aplicado um piso seguro equivalente a `ln(2^-16)`, evitando propagação de valores indefinidos e mantendo a saída finita em silêncio ou ausência de sinal.

### 7.6. DCT-II ortonormal

A DCT usa 32 bandas Mel para produzir 13 coeficientes. Os fatores de normalização são:

```text
C[0] = sqrt(1/32)
C[k] = sqrt(2/32), k > 0
```

Os coeficientes são representados em Q12. Uma ROM de quarto de onda foi substituída por uma função compacta com simetria de cosseno, reduzindo a quantidade de constantes armazenadas.

O resultado de cada coeficiente é emitido como inteiro assinado Q16.16 de 32 bits.

## 8. Estabilização para ambiente ruidoso

O módulo `rtl/analysis/feature_temporal_stabilizer.sv` aplica uma média móvel exponencial por coeficiente:

```text
y[n] = y[n-1] + alpha × (x[n] - y[n-1])
```

Configuração atual:

```text
alpha = 1/4
ALPHA_SHIFT = 2
ALPHA_Q = 1
```

O primeiro valor de cada coeficiente é aceito diretamente. Depois disso, cada atualização move o estado apenas 25% em direção ao novo valor. Isso reduz variações causadas por ruído impulsivo e flutuações curtas do ambiente.

O módulo também limita o resultado aos limites de um número assinado de 32 bits, evitando wrap-around durante a atualização.

Essa suavização é deliberadamente aplicada aos MFCCs, e não às amostras de áudio. Dessa forma, o detector ainda recebe a dinâmica espectral original, mas a interface de decisão ou classificação observa características menos instáveis.

## 9. Remoção do protocolo legado do Raspberry Pi

### 9.1. Caminho removido

O caminho antigo era:

```text
FFT DMA
    -> FIFO de transporte
    -> serializer tagged FFT
    -> I2S externo
    -> Raspberry Pi
```

Ele foi criado para transmitir real, imaginário, índice e expoente para o Raspberry Pi. Com o processamento local, esse caminho passou a ser desnecessário e introduzia:

- latência adicional;
- possibilidade de overflow da FIFO;
- necessidade de sincronização e clock de transmissão;
- largura e formato de pacote fixos;
- tráfego desnecessário de bins que não seriam usados pelo MFCC;
- risco de incompatibilidade com FFT de 1024 pontos.

### 9.2. Caminho atual

O caminho atual é:

```text
FFT DMA
    -> fft_bin_valid/index/real/imag/last
    -> fft_feature_analyzer
    -> MFCC
```

Em `rtl/core/aces.sv`:

- as instâncias `fft_tx_bridge_fifo` e `i2s_fft_tx_adapter` foram removidas;
- `fft_dma_reader` transmite diretamente para as saídas internas `fft_tx_*`;
- os pinos `tx_i2s_*` são mantidos apenas como compatibilidade e são amarrados a zero;
- `tx_overflow_o` também permanece zerado, pois não existe mais FIFO de transporte.

No projeto Quartus, `rtl/common/fft_tx_bridge_fifo.sv` e `rtl/frontend/i2s_fft_tx_adapter.sv` foram removidos do script de fontes `quartus/de10lite_audio_fft_sources.tcl`. Os arquivos antigos podem continuar no repositório por compatibilidade histórica e para testes de legado, mas não fazem parte da hierarquia sintetizada do top-level DE10-Lite.

## 10. Projeto Quartus da DE10-Lite

O projeto está em `quartus/`.

### 10.1. Dispositivo

```text
Device: 10M50DAF484C7G
Family: MAX 10
Top-level: de10lite_audio_fft_top
```

### 10.2. Inicialização de memórias

Como o projeto usa ROMs de janela, banco Mel, logaritmo e twiddle factors, a configuração do MAX 10 foi ajustada para permitir preload de memória:

```tcl
set_global_assignment -name MAX10FPGA_CONFIGURATION_SCHEME "Internal Configuration"
set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "Single Image with ERAM"
```

Sem esse modo, o Quartus emitia o erro 16031, informando que o modo interno selecionado não suportava ROM ou inicialização de memória.

### 10.3. Arquivo de timing

Foi criado `quartus/de10lite_audio_fft.sdc` com:

```tcl
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty
```

Isso evita a análise incorreta usando um clock implícito de 1 ns. O clock SCK do microfone é gerado internamente e ainda precisa de uma restrição de clock gerado específica para eliminar completamente o aviso de clock sem assignment associado.

### 10.4. Pinagem principal

A pinagem foi convertida para assignments estáticos no QSF, incluindo:

- clock P11;
- keys B8/A7;
- switches C10, C11, D12, C12, A12, B12, A13, A14, B14 e F15;
- LEDs da DE10-Lite;
- três displays de sete segmentos;
- GPIOs do microfone e diagnóstico.

O uso de assignments estáticos evita depender de loops Tcl dentro do QSF, que causavam falhas de interpretação no Quartus.

## 11. Verificação e validação

### 11.1. Testes Questa

Foram executados testes unitários no Questa Altera Starter FPGA Edition 2025.2.

#### Potência espectral

Arquivo:

```text
tb/unit/tb_fft_power_math.sv
```

Resultado:

```text
tb_fft_power_math PASSED
```

Valida a soma dos quadrados real/imaginário e o tratamento da escala do expoente.

#### ROM Mel

Arquivo:

```text
tb/unit/tb_mel_coeff_rom.sv
```

Resultado:

```text
tb_mel_coeff_rom PASSED
```

O teste confirma o carregamento do arquivo HEX e os valores básicos da tabela. Durante a primeira execução foi identificado apenas um problema de diretório de trabalho do Questa; a simulação foi repetida a partir da raiz do projeto e passou.

#### Estabilizador temporal

Arquivo:

```text
tb/unit/tb_feature_temporal_stabilizer.sv
```

Resultado:

```text
tb_feature_temporal_stabilizer PASSED
```

Valida primeiro valor direto, atualização EMA e emissão dos sinais de validade/fim de frame.

### 11.2. Compilação Quartus

Comando utilizado no Windows:

```powershell
Set-Location C:\Users\jvcte\quadri_poli\ACES\quartus
& C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe `
    --flow compile de10lite_audio_fft
```

Resultado final:

```text
Quartus Prime Full Compilation was successful.
0 errors
```

Etapas concluídas:

- Analysis & Synthesis: 0 erros;
- Fitter: 0 erros;
- Assembler: 0 erros;
- Timing Analyzer: 0 erros;
- arquivos de programação gerados.

Recursos reportados na síntese:

| Recurso | Quantidade |
|---|---:|
| Células lógicas | 8366 |
| Segmentos RAM | 363 |
| Elementos DSP | 29 |
| Pinos de entrada | 13 |
| Pinos de saída | 34 |
| Pinos bidirecionais | 36 |

## 12. Problemas conhecidos

### 12.1. Fechamento de timing

Com o clock real de 50 MHz, o timing analyzer reportou no corner lento:

```text
Worst-case setup slack: aproximadamente -13 ns
Worst-case hold slack: aproximadamente +0,28 ns
```

No corner rápido o setup apresentou slack positivo, aproximadamente `+6,1 ns`. Portanto, a implementação está roteável e compilável, mas ainda não está comprovadamente fechada para todos os corners de operação.

As causas prováveis são:

- caminho combinacional extenso no núcleo R2FFT legado;
- multiplicadores e somadores do analisador sintetizados no mesmo domínio de 50 MHz;
- clock de áudio gerado por lógica e ainda não descrito como clock gerado no SDC;
- conexões antigas do núcleo R2FFT com warnings de conectividade;
- ausência de pipeline adicional em alguns caminhos de pós-processamento.

### 12.2. Warnings do núcleo R2FFT

O Quartus reporta diversos sinais sem fonte ou com truncamentos dentro de `submodules/R2FFT`. Esses warnings já pertenciam ao núcleo legado e não foram modificados nesta etapa. Eles devem ser investigados antes de considerar o caminho FFT definitivamente pronto para produção.

### 12.3. Memórias inferidas

O MAX 10 não possui blocos chamados M10K com a mesma nomenclatura de outras famílias. O Quartus remapeia os atributos de RAM para os blocos disponíveis, emitindo warnings informativos. A síntese confirmou a inferência de centenas de segmentos RAM.

### 12.4. GPIOs de transporte antigos

Os sinais `GPIO[4]`, `GPIO[5]` e `GPIO[6]` ainda estão fisicamente declarados, mas não devem ser usados como saída FFT. Eles são mantidos apenas para compatibilidade elétrica e de pinagem durante o bring-up.

## 13. Melhorias futuras recomendadas

### Prioridade alta

1. Corrigir o fechamento de timing do R2FFT para o corner lento.
2. Descrever o SCK do microfone como clock gerado no SDC.
3. Investigar os sinais sem fonte reportados em `r2fft_tribuf_impl.sv`.
4. Criar um teste de integração que injete uma sequência conhecida no pipeline completo de 1024 pontos.
5. Validar o arquivo `.sof` diretamente na DE10-Lite com microfone real.

### Prioridade média

1. Expandir o banco Mel para incluir explicitamente o bin de Nyquist.
2. Implementar saturação explícita em todas as reduções de largura reportadas pelo Quartus.
3. Substituir a função procedural da DCT por ROMs ou multiplicadores compartilhados com pipeline explícito.
4. Avaliar dois núcleos FFT em paralelo para aumentar a margem de processamento entre hops.
5. Adicionar métricas de energia, clipping e ruído estimado para controle adaptativo.

### Robustez em ambiente ruidoso

1. Estimar noise floor por banda Mel durante períodos sem voz.
2. Aplicar subtração espectral ou flooring adaptativo antes do logaritmo.
3. Implementar voice activity detection para evitar atualizar o modelo com silêncio ruidoso.
4. Tornar `alpha` do estabilizador configurável por estado de ruído.
5. Avaliar CMVN — normalização média e variância — sobre sequências de MFCC.
6. Medir desempenho com ruído estacionário, ruído impulsivo e fala distante.

## 14. Arquivos principais alterados nesta etapa

| Arquivo | Função |
|---|---|
| `rtl/core/aces.sv` | Remove FIFO/serializer e conecta DMA diretamente ao analisador |
| `rtl/common/fft_dma_reader.sv` | Permite leitura configurável de 1024 bins |
| `rtl/analysis/fft_feature_analyzer.sv` | Ajusta largura Q16 da ROM Mel |
| `rtl/analysis/mel_coeffs_1024_q16.hex` | Coeficientes Mel em palavras de 16 bits |
| `quartus/de10lite_audio_fft_sources.tcl` | Exclui fontes do protocolo legado |
| `quartus/de10lite_audio_fft.qsf` | Configuração DE10-Lite, ERAM e SDC |
| `quartus/de10lite_audio_fft.sdc` | Clock principal de 50 MHz |

## 15. Conclusão

A branch `lab-dig2-initial` possui um caminho funcional de processamento local na DE10-Lite: o Raspberry Pi deixou de participar da análise, os resultados da FFT são consumidos diretamente na FPGA e as características MFCC são produzidas localmente em ponto fixo.

A integração Quartus foi validada até a geração dos arquivos de programação, e os módulos críticos alterados possuem testes unitários aprovados no Questa. O principal item ainda aberto é o fechamento de timing no corner lento, além da validação em hardware real com sinais de áudio e ruído controlados.
