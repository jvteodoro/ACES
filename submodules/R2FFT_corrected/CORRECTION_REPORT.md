# Relatório de correção e validação do R2FFT

## 1. Objetivo

Este projeto é uma versão corrigida e rastreada pelo repositório principal a
partir do submódulo original `submodules/R2FFT`. O objetivo foi corrigir os
problemas de largura, tipagem, endereçamento e integração com memória
identificados durante a adaptação do processamento FFT para a FPGA DE10-Lite
(MAX 10), mantendo o submódulo original intacto como referência.

Configuração validada:

| Parâmetro | Valor |
|---|---:|
| FPGA | Intel/Altera MAX 10 `10M50DAF484C7G` |
| Comprimento FFT | 1024 pontos |
| Largura de amostra | 18 bits |
| Largura complexa | 36 bits |
| Pipeline | `PL_DEPTH=3` |
| Memória de dados | 512 palavras por banco |
| ROM de twiddle | 256 palavras, Q1.15 |

## 2. Problema principal encontrado

O núcleo `R2FFT` trabalha com amostras complexas empacotadas em
`2*FFT_DW` bits. Com `FFT_DW=18`, cada palavra possui 36 bits. Entretanto, a
IP `dpram.v` original havia sido gerada com portas de apenas 32 bits.

Consequências:

* os quatro bits superiores de cada escrita eram truncados;
* os quatro bits superiores da leitura permaneciam sem fonte explícita;
* o problema afetava principalmente a parte imaginária do dado empacotado;
* os resultados de potência, magnitude e MFCC poderiam ser corrompidos mesmo
  quando os sinais de controle aparentassem funcionar.

Esse warning não era apenas cosmético. A correção foi feita em
`quartus/dpram.v`, criando o módulo `r2fft_dpram` com:

* dados de 36 bits;
* endereços de 9 bits;
* 512 palavras;
* operação dual-port;
* família de dispositivo MAX 10.

As seis instâncias da memória triple-buffer foram atualizadas para usar essa
IP corrigida.

## 3. Correções implementadas

### 3.1 Integração da DPRAM

O módulo original `dpram` foi isolado e renomeado para `r2fft_dpram`. A
interface agora coincide exatamente com os sinais `FFT_DW*2` do núcleo. O
Quartus confirmou durante a análise:

```text
width_a = 36
width_b = 36
widthad_a = 9
widthad_b = 9
numwords_a = 512
numwords_b = 512
```

### 3.2 Integração da ROM de twiddle

A ROM original possui coeficientes Q1.15 de 16 bits, enquanto a interface do
R2FFT com `FFT_DW=18` possui 18 bits. A ROM foi mantida em 16 bits para
preservar sua escala numérica original, mas a integração agora faz uma
extensão explícita para 18 bits:

```systemverilog
wire [15:0] twdr_cos_rom;
wire [FFT_DW-1:0] twdr_cos = {{(FFT_DW-16){1'b0}}, twdr_cos_rom};
```

Isso remove a conversão implícita e deixa documentada a convenção de escala.

### 3.3 Contadores e BFP

Foram corrigidos avisos de conversão implícita nos seguintes pontos:

* contador de bit-reversal;
* contador de estágios FFT;
* detector de largura de palavra BFP;
* acumulador do expoente BFP;
* constantes de zero, um e `FFT_DW-2`.

As correções usam constantes com largura explícita e preservam a sequência
original de contagem. Não foi feita alteração da latência do pipeline.

### 3.4 Gerador de endereços

O `fftAddressGenerator` original misturava sinais de largura `FFT_N-1` com
máscaras de largura `FFT_N`, além de utilizar constantes não dimensionadas.

A versão corrigida:

* define `MEM_ADDR_W = FFT_N-1`;
* dimensiona explicitamente a constante um;
* dimensiona as máscaras inferior e superior com a largura do endereço;
* preserva a fórmula de geração de `MemAddr`;
* preserva a reversão de bits do endereço de twiddle.

### 3.5 Multiplexadores de triple-buffer

Os modos dos bancos eram parâmetros inteiros atribuídos diretamente a
registradores de 2 bits. Na versão corrigida, os quatro estados são atribuídos
com literais de 2 bits (`2'd0` a `2'd3`). Isso elimina warnings de truncamento
sem alterar a tabela de rotação dos três bancos.

### 3.6 Interface DMA

O Quartus detectou que `dmaact_i` não tinha dependência em nenhuma saída. A
causa era que o enable era usado apenas no caminho de controle de leitura, mas
as RAMs mantinham a leitura efetivamente sempre ativa.

A saída registrada foi tornada semanticamente explícita:

```systemverilog
dmadr_real_o <= dmaact ? dmadr_real : {FFT_DW{1'b0}};
dmadr_imag_o <= dmaact ? dmadr_imag : {FFT_DW{1'b0}};
```

Assim, o dado só é exposto quando o acesso DMA está ativo.

### 3.7 Configuração MAX 10

O projeto Quartus foi adaptado para a DE10-Lite:

* família `MAX 10`;
* dispositivo `10M50DAF484C7G`;
* configuração `Single Image with ERAM`;
* ROM inicializada compatível com o modo de configuração da MAX 10;
* quatro processadores de compilação configurados;
* SDC com `derive_clock_uncertainty`.

## 4. Referência numérica Python

O arquivo `verification/r2fft_reference.py` contém um modelo independente
para:

* FFT normalizada por estágio;
* aritmética aproximada com twiddles Q1.15;
* saturação para a largura configurada;
* cálculo de largura BFP;
* vetores de teste determinísticos.

Os vetores incluem:

1. impulso;
2. seno no bin 64;
3. seno de Nyquist;
4. sinal complexo em escala máxima;
5. sinal multi-tom com componente de ruído determinística.

Os testes podem ser executados sem dependências externas:

```text
python -m unittest -v verification/test_r2fft_reference.py
```

Resultado obtido:

```text
Ran 3 tests
OK
```

## 5. Validação Quartus

O projeto isolado `quartus/r2fft_tribuf_impl.qpf` foi compilado no Quartus
Prime Standard 25.1 para MAX 10.

Resultado da compilação completa anterior à limpeza final dos warnings de
interface:

```text
Analysis & Synthesis: successful
Fitter: successful
Assembler: successful
Timing Analyzer: successful
Full Compilation: successful, 0 errors
```

Na análise incremental posterior às correções de tipagem, a síntese terminou
com:

```text
0 errors
3 warnings
```

Os warnings restantes eram de infraestrutura ou configuração, não de
truncamento RTL:

* atribuições de pinos não definidas no núcleo isolado;
* avisos de pinos reservados/programação;
* incerteza de clock durante a compilação anterior à atualização do SDC.

O warning funcional de `dmaact_i` foi corrigido depois dessa análise
incremental e deve ser confirmado na próxima compilação completa.

O pior slack de setup observado no núcleo isolado foi positivo, de
aproximadamente `0,240 ns` no pior canto lento de 10 ns.

## 6. Validação Questa

O testbench `verification/tb_fft_address_generator.sv` testa todos os estágios
do gerador de endereços para uma FFT de 1024 pontos.

Para cada um dos 10 estágios são verificados:

* 511 ciclos ativos;
* `MemAddr` contra a fórmula de referência;
* endereço da ROM de twiddle;
* `act` durante o processamento;
* `done` no encerramento do estágio.

O teste é executado por:

```powershell
.\verification\run_address_test.ps1
```

Resultado obtido no Questa Altera Starter FPGA Edition 2025.2:

```text
Compiling module fftAddressGenerator
Compiling module tb_fft_address_generator
Errors: 0, Warnings: 0

tb_fft_address_generator PASSED
Errors: 0, Warnings: 0
```

O tempo total simulado foi aproximadamente `51416 ns`.

## 7. Validação end-to-end do ACES com `R2FFT_corrected`

Após a integração, os seguintes caminhos foram alterados para usar esta
versão corrigida:

* `rtl/core/aces.sv` instancia `r2fft_tribuf_impl_corrected`;
* o projeto Quartus DE10-Lite inclui exclusivamente os HDL/IP de
  `submodules/R2FFT_corrected`;
* o filelist real do Questa usa o mesmo núcleo corrigido;
* o wrapper de simulação preserva o modelo de memória de 512 pontos/18 bits,
  enquanto a síntese usa os IPs MAX 10 de 36 bits e 512 palavras.

### 7.1 Questa integrado

Comando executado:

```bash
./sim/manifest/scripts/run_questa.sh top_level_fft_isolated real
```

Resultado:

```text
tb_top_level_fft_isolated PASSED
auto   rmse=257.703188 max_abs=743.120580
manual rmse=257.703188 max_abs=743.120580
Errors: 0, Warnings: 3498
```

Os 512 bins foram lidos tanto pelo `fft_dma_reader` quanto por uma leitura
DMA manual independente. Os resultados automático e manual foram idênticos;
o erro observado é de quantização fixa em relação ao CSV de referência.
Os warnings restantes são majoritariamente avisos repetitivos do
`unique/priority case` no top-level de teste, não erros de compilação ou
falhas de protocolo.

### 7.2 Quartus DE10-Lite

Foi executado o fluxo completo com Quartus Prime Standard 25.1:

```powershell
quartus_sh --flow compile quartus/de10lite_audio_fft.qpf
```

Resultados do projeto `de10lite_audio_fft`:

* Analysis & Synthesis: **successful**, 0 erros;
* Fitter: **successful**, 0 erros;
* Timing Analyzer: **successful**, 0 erros;
* recursos: 7.508/49.760 elementos lógicos (15%) e 160.310/1.677.312 bits
  de memória (10%);
* arquivos `.sof` e `.pof` gerados em `quartus/output_files_de10lite/`.

Ainda há avisos de timing (`worst-case slack = -12,386 ns`), de clock SCK
derivado sem restrição própria e de 27 pinos sem localização exata. A síntese
foi aprovada, mas o timing não deve ser considerado fechado até que o clock
de áudio e as restrições de pinos sejam revisados.

## 8. Limitações e próximos testes

Esta etapa validou exaustivamente o gerador de endereços e a referência
numérica, mas ainda não substitui uma validação end-to-end do núcleo completo.
Os próximos testes necessários são:

* testbench do triple-buffer e da DPRAM de 36 bits;
* teste de latência da ROM de twiddle;
* impulso completo através do `R2FFT_tribuf`;
* tons em bins baixos, médios e próximos de Nyquist;
* sinais complexos e valores máximo positivo/negativo;
* comparação dos 512 bins DMA com a referência Python;
* validação do expoente BFP e da reconstrução da escala;
* compilação Quartus final após a correção do enable DMA;
* análise de timing e recursos no projeto integrado da DE10-Lite.

Nenhuma correção foi aplicada por supressão de warning. Cada warning deve
continuar sendo removido somente depois de demonstrada a preservação da
latência, da escala numérica e da sequência de controle.

## 9. Conclusão

A versão `R2FFT_corrected` elimina o defeito funcional mais grave do núcleo
original: a incompatibilidade entre a largura de 36 bits usada pelo FFT de 18
bits e a DPRAM de 32 bits. Também remove as principais conversões implícitas
de largura e documenta uma referência Python para a validação numérica.

O gerador de endereços, o caminho DMA integrado e a síntese completa do ACES
foram validados com `R2FFT_corrected`. O bitstream foi gerado para a
DE10-Lite. Permanecem como trabalho de fechamento a eliminação dos warnings de
timing/pinos e a validação física com microfone em ambiente ruidoso; esses
testes não podem ser substituídos por simulação RTL.

## 10. Fechamento de timing do ACES na DE10-Lite

O caminho crítico inicial não estava no `R2FFT_corrected`, mas no
`fft_feature_analyzer`: quadratura dos bins, soma, reescala BFP e escrita em
`power_ram` ocorriam no mesmo ciclo. Depois, os caminhos dominantes eram a
multiplicação Mel com o acumulador, o cálculo de log entre as RAMs
`mel_energy`/`log_energy` e a geração combinacional do coeficiente DCT. A pior
folga inicial chegou a `-12,884 ns`.

Foram aplicadas estas correções no RTL:

* cálculo de potência dividido em captura, quadratura e escala/escrita, com
  registradores `preserve` para impedir o recolhimento dos estágios;
* multiplicação Mel separada da soma pelos estados `MEL_MUL` e `MEL_ACC`;
* leitura de `mel_energy` separada do cálculo/escrita do log pelos estados
  `LOG_PREP` e `LOG_ACC`;
* coeficientes DCT pré-calculados em `dct_coeff_rom`, removendo a aritmética de
  fase do caminho crítico.

A latência aumentou somente entre o último bin e o MFCC; a entrada continua
aceitando um bin por ciclo e a taxa de áudio não foi reduzida.

O `sck_o` era detectado como clock pelo TimeQuest, mas não possuía clock
associado. Foi adicionada uma restrição `create_generated_clock` chamada
`I2S_SCK` em `quartus/de10lite_audio_fft.sdc`, derivada de
`MAX10_CLK1_50`. Como o Quartus exige divisor inteiro, foi usado
`-divide_by 16` (3,125 MHz), uma restrição conservadora em relação à média de
3,072 MHz do NCO. A tentativa fracionária foi removida porque era rejeitada
pelo fitter.

Após as mudanças, o Questa continuou passando:

```text
tb_top_level_fft_isolated PASSED
auto   rmse=257.703188 max_abs=743.120580
manual rmse=257.703188 max_abs=743.120580
max_abs(auto-manual)=0.000000
Errors: 0, Warnings: 3498
```

O TimeQuest final do projeto `de10lite_audio_fft` apresentou:

| Canto | Setup | Hold |
|---|---:|---:|
| Slow 1200 mV, 85 °C | **+0,780 ns** | +0,256 ns |
| Slow 1200 mV, 0 °C | **+2,408 ns** | +0,255 ns |
| Fast 1200 mV, 0 °C | **+11,786 ns** | +0,095 ns |

O `I2S_SCK` também ficou positivo em setup e hold. O TimeQuest terminou com
`0 errors, 0 warnings`; portanto, a violação de timing foi fechada sem falsos
caminhos ou relaxamento artificial do clock.
