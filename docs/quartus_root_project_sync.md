# Sincronizacao do Projeto Quartus da Raiz

## Objetivo

Este repositório passou a usar a configuracao mais nova da pasta `quartus/top_level_test_restored` como referencia funcional, mas promovida para a raiz do projeto para que a compilacao oficial aconteca por `quartus/top_level_test.qpf`.

Depois destas alteracoes, a arvore da raiz e a que deve ser usada para editar RTL, revisar IPs e rodar a compilacao.

## O que foi alterado

### 1. Projeto Quartus da raiz alinhado com a versao restaurada

Arquivo principal ajustado:

- `quartus/top_level_test.qsf`

Alteracoes aplicadas:

- Remocao das configuracoes de SignalTap que existiam so na versao da raiz e nao faziam parte da snapshot restaurada.
- Manutencao do mesmo mapeamento de pinos, particao e `SOURCE_TCL_SCRIPT_FILE` da versao restaurada.
- Preservacao do fluxo de compilacao a partir de `quartus/top_level_test.qpf`.

Resultado:

- O projeto da raiz volta a refletir a configuracao do snapshot restaurado, sem dependencias extras de debug que podiam poluir a compilacao.

### 2. Manifesto de fontes consolidado na raiz

Arquivo ajustado:

- `quartus/top_level_test_sources.tcl`

Alteracoes aplicadas:

- O RTL principal continua vindo da raiz (`rtl/...`) e do submodulo `submodules/R2FFT/...`.
- Os IPs da FFT passaram a ser promovidos a partir de `rtl/ip/fft`, em vez de depender dos `qip` duplicados dentro de `submodules/R2FFT/quartus`.
- O `twrom.mif` usado pela compilacao agora e explicitamente o da raiz:
  - `rtl/ip/fft/twrom.mif`

Resultado:

- O projeto Quartus da raiz deixa de misturar o `twrom` do R2FFT com um `.mif` antigo e incompatível.

### 3. IP da ROM de twiddle atualizado na raiz

Arquivos ajustados:

- `rtl/ip/fft/twrom.v`
- `rtl/ip/fft/twrom_bb.v`
- `rtl/ip/fft/twrom.mif`

Alteracoes aplicadas:

- A interface do `twrom` da raiz foi corrigida para a geometria realmente usada pelo R2FFT:
  - endereco: `8 bits`
  - largura de dado: `16 bits`
  - profundidade: `256 palavras`
- O conteudo de `rtl/ip/fft/twrom.mif` foi sincronizado com o `twrom` canônico do R2FFT:
  - `submodules/R2FFT/quartus/twrom.mif`

Resultado:

- O warning abaixo deixa de fazer sentido estruturalmente:

`Critical Warning (127005): Memory depth (256) in the design file differs from memory depth (128) in the Memory Initialization File ...`

Antes:

- o Quartus elaborava o `twrom` de `256x16` do R2FFT
- mas resolvia `twrom.mif` para um arquivo antigo de `128x18` em `rtl/ip/fft`

Agora:

- o `twrom` promovido na raiz tem a mesma geometria do IP realmente usado pela FFT
- e o manifesto do projeto aponta diretamente para esse conjunto canônico

## Como o repositório fica organizado depois das alteracoes

### Caminho oficial de compilacao

Use sempre:

- `quartus/top_level_test.qpf`

### Fonte canônica de cada bloco

- Top-level e RTL de integracao: `rtl/...`
- Projeto Quartus: `quartus/top_level_test.qpf` e `quartus/top_level_test.qsf`
- Manifesto de fontes: `quartus/top_level_test_sources.tcl`
- IPs da FFT usados pela compilacao da raiz: `rtl/ip/fft/...`
- Logica do core R2FFT: `submodules/R2FFT/...`
- ROM de estimulos de audio: `tools/signals_rom.mif` via `rtl/ip/rom/signals_rom_ip.*`

### Papel de `quartus/top_level_test_restored`

A pasta restaurada continua util como snapshot de referencia, mas nao deve mais ser o ponto principal de uso do projeto.

Na pratica:

- editar RTL na raiz
- abrir o projeto Quartus da raiz
- tratar a pasta restaurada como backup/referencia historica

## Fluxo recomendado daqui para frente

1. Abrir `quartus/top_level_test.qpf` no Quartus Prime Lite 25.1.
2. Rodar uma compilacao completa da raiz.
3. Conferir se os artefatos regenerados em `quartus/output_files` nao trazem mais o warning `127005`.
4. Se desejar uma recompilacao limpa, o Quartus pode regenerar normalmente:
   - `quartus/db`
   - `quartus/incremental_db`
   - `quartus/output_files`

## Validacao realizada nesta sessao

Validacoes concluidas:

- Confirmado que `rtl/core/aces.sv` e `rtl/core/aces_audio_to_fft_pipeline.sv` da raiz ja estavam alinhados com a versao restaurada.
- Confirmado que `rtl/top/top_level_test.sv` da raiz ja refletia funcionalmente a versao restaurada.
- Confirmado que `submodules/R2FFT/quartus/r2fft_tribuf_impl.sv` e os arquivos do R2FFT usados na compilacao batem com a snapshot restaurada.
- Confirmado que `rtl/ip/fft/twrom.mif` agora e identico a `submodules/R2FFT/quartus/twrom.mif`.
- Confirmado que o manifesto da raiz passou a referenciar somente:
  - `rtl/ip/fft/dpram.qip`
  - `rtl/ip/fft/twrom.qip`
  - `rtl/ip/fft/twrom.mif`

Limitacao desta sessao:

- A compilacao do Quartus nao pode ser executada diretamente daqui porque este ambiente WSL nao esta conseguindo iniciar os executaveis `.exe` do Quartus instalado no Windows.
- O erro observado ao tentar invocar o binario foi:
  - `WSL ... UtilBindVsockAnyPort:307: socket failed 1`

Isso significa que a verificacao final de synthesis/fitter precisa ser rodada do lado Windows, ou em um WSL com interop funcional.

## Resumo final

Depois destas alteracoes, a raiz do repositório passou a ser a versao operacional mais nova do projeto Quartus. O conflito entre o `twrom` da FFT e o `.mif` antigo foi eliminado estruturalmente, e a compilacao oficial deve partir de `quartus/top_level_test.qpf`.
