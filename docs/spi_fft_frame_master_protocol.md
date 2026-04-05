# SPI FFT Frame Master Protocol

## Objetivo

`spi_fft_frame_master` implementa o caminho novo de exportacao FFT em que:

- a FPGA e o master SPI;
- o Analog Discovery atua como slave/passive receiver;
- cada frame FFT completo corresponde a exatamente uma transacao SPI;
- em idle nao existe trafego espurio: `CS_N=1`, `SCLK=0`, `MOSI=0`.

Arquivo principal:

- `rtl/frontend/spi_fft_frame_master.sv`

## Formato do frame

Uma transacao SPI completa contem:

1. `Header Word 0`
2. `Header Word 1`
3. `Header Word 2`
4. `COUNT` palavras de payload

Codificacao:

```text
Header Word 0
  [31:16] SOF
  [15:8]  VERSION
  [7:0]   TYPE

Header Word 1
  [31:16] SEQ
  [15:0]  COUNT

Header Word 2
  [31:16] FLAGS
  [15:0]  EXP

Payload Word
  [31:23] BIN_ID
  [22]    PART
  [21:18] FLAGS_LOCAL
  [17:0]  VALUE
```

Valores atuais:

- `SOF = 16'hA55A`
- `VERSION = 8'h01`
- `TYPE = 8'h01`
- `PART = 0` para real
- `PART = 1` para imag

## Regras de transmissao

- `CS_N` sobe e desce exatamente uma vez por frame.
- `COUNT` representa numero de palavras de payload, nao numero de bins.
- cada bin gera exatamente 2 palavras:
  - real
  - imag
- os `BIN_ID`s saem na mesma ordem produzida por `fft_dma_reader`.
- `SEQ` incrementa quando o frame e fechado por `fft_last_i`.
- `EXP` e derivado de `bfpexp_i` e preservado em 16 bits.
- `FLAGS_LOCAL` sao transmitidos como zero no RTL atual, mas o campo existe e o parser os preserva.
- `FLAGS` globais sao hoje configurados por instancia do modulo; o valor padrao em `aces` e `16'h0000`.

## Comportamento em idle

O modulo nao transmite dados parciais.

Enquanto o ultimo bin do frame nao chega:

- o frame fica sendo montado no buffer interno;
- `frame_pending_o` permanece baixo;
- `spi_active_o` permanece baixo;
- `CS_N` fica alto;
- `SCLK` nao oscila.

Quando `fft_last_i` chega:

1. o metadata do frame e fechado;
2. o frame entra na fila de transmissao;
3. o master baixa `CS_N`;
4. transmite `header -> payload`;
5. volta para idle ao fim da ultima palavra.

Isso evita “lixo” nos periodos em que a FFT ainda nao disponibilizou uma janela completa.

## Timing SPI

O bloco usa SPI mode 0:

- `CPOL = 0`
- `CPHA = 0`

Ou seja:

- `SCLK` repousa em zero;
- `MOSI` e apresentado durante a fase baixa;
- o receptor amostra o bit na borda de subida.

Bits e bytes:

- bytes saem em ordem big-endian;
- cada byte sai em `MSB-first`;
- as palavras de 32 bits saem na mesma ordem usada pelo parser Python.

## Alinhamento com o software WaveForms

O decoder no lado Windows/WSL espera exatamente esse contrato:

- `windows_bridge/waveforms_spi_capture.py`
  - separa frames por transicao de `CS`;
  - amostra bits no modo 0;
  - reconstrui bytes em `MSB-first`;
  - converte grupos de 4 bytes em palavras de 32 bits com `byteorder="big"`.

- `core/parser.py`
  - valida `SOF`, `VERSION` e `TYPE`;
  - valida `COUNT`;
  - faz sign extension correta de `VALUE[17:0]`;
  - reconstroi pares `real/imag` por `BIN_ID`.

Em outras palavras: o hardware novo e o pipeline Python compartilham o mesmo framing e a mesma codificacao bit a bit.

## Mapeamento no top-level

No `rtl/top/top_level_test.sv`, o caminho SPI master para o Analog Discovery sai pelos GPIOs:

- `GPIO_1_D30`: `SCLK`
- `GPIO_1_D32`: `CS_N`
- `GPIO_1_D34`: `MOSI`
- `GPIO_1_D21`: `frame_pending`
- `GPIO_1_D23`: overflow de debug

O caminho SPI slave legado continua disponivel em paralelo para a bancada com Raspberry Pi.

## Benchs de verificacao

Benchs principais:

- `tb/unit/tb_spi_fft_frame_master.sv`
- `tb/integration/tb_fft_frame_spi_master_link.sv`

Cobertura principal:

- idle limpo sem clocks espurios;
- nenhuma transmissao antes do frame completo;
- `SEQ`, `COUNT`, `FLAGS`, `EXP` e payload empacotados corretamente;
- valores positivos e negativos em `VALUE`;
- integracao `fft_dma_reader -> spi_fft_frame_master`.

Comandos:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_frame_master
sim/manifest/scripts/run_questa.sh fft_frame_spi_master_link
```
