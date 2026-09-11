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

## 7. Limitações e próximos testes

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

## 8. Conclusão

A versão `R2FFT_corrected` elimina o defeito funcional mais grave do núcleo
original: a incompatibilidade entre a largura de 36 bits usada pelo FFT de 18
bits e a DPRAM de 32 bits. Também remove as principais conversões implícitas
de largura e documenta uma referência Python para a validação numérica.

O gerador de endereços corrigido foi aprovado no Questa sem erros ou warnings,
e o projeto isolado foi aceito pelo fluxo Quartus para a MAX 10. A validação
end-to-end dos valores FFT ainda deve ser executada antes de conectar o núcleo
ao analisador MFCC definitivo.
