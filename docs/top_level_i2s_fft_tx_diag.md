# Top-Level de Diagnostico do `i2s_fft_tx_adapter`

## Objetivo

`top_level_i2s_fft_tx_diag` existe para isolar a transmissao tagged-I2S da FPGA e
eliminar a FFT, a DMA, o caminho do microfone e a geracao de estimulos da lista
de suspeitos.

Em vez de depender do pipeline completo, este topo:

- reutiliza o mesmo envelope de I/O do `top_level_test`,
- preserva os mesmos pinos fisicos usados hoje pelo host,
- alimenta o `i2s_fft_tx_adapter` com uma sequencia totalmente deterministica,
- repete essa sequencia continuamente para permitir captura longa no Raspberry Pi.

Isso permite depurar em camadas:

1. nivel eletrico e de clock,
2. nivel bruto de palavra I2S,
3. nivel de tags e padding,
4. nivel logico de janela FFT no software.

## Arquivos relacionados

- `rtl/top/top_level_i2s_fft_tx_diag.sv`
- `tb/integration/tb_top_level_i2s_fft_tx_diag.sv`
- `sim/manifest/filelists/mock_integration_top_level_i2s_fft_tx_diag.f`
- `quartus/top_level_i2s_fft_tx_diag_sources.tcl`

## Pinos reutilizados do `top_level_test`

O modulo foi escrito com o mesmo port map do topo principal para permitir
reaproveitar o mesmo pinout da placa.

Pinos principais mantidos:

- `GPIO_0_D0`: clock externo do sistema (`clk`)
- `GPIO_0_D1`: reset externo ativo em nivel alto (`rst`)
- `GPIO_1_D27`: `tx_i2s_sck_o` para o Raspberry Pi
- `GPIO_1_D29`: `tx_i2s_ws_o` para o Raspberry Pi
- `GPIO_1_D31`: `tx_i2s_sd_o` para o Raspberry Pi

Pinos extras de status:

- `GPIO_0_D11`: `fft_ready_o`
- `GPIO_0_D12`: `fifo_full_o`
- `GPIO_0_D13`: `fifo_empty_o`
- `GPIO_0_D14`: overflow latched
- `GPIO_0_D17`: pulso de fim de janela
- `GPIO_0_D19`: heartbeat por amostra aceita
- `GPIO_1_D0..D5`: espelhos de sinais de status para probe rapido

Displays locais:

- `SW1:SW0 = 00`: BFPEXP fixo
- `SW1:SW0 = 01`: payload real fixo
- `SW1:SW0 = 10`: payload imag fixo
- `SW1:SW0 = 11`: estado interno resumido

## Padrao transmitido

Parametros default do topo:

- `DIAG_WINDOW_BINS = 512`
- `DIAG_BFPEXP_HOLD_FRAMES = 1`
- `I2S_CLOCK_DIV = 8`
- `I2S_SLOT_W = 32`
- `I2S_SAMPLE_W = 18`

Constantes transmitidas:

- `BFPEXP = -18`
- `FFT real = 18'h15555 = 87381`
- `FFT imag = -18'h0AAAB = -43691`

Cada janela emitida pelo topo e:

1. um frame `BFPEXP` com packet index `0`
2. `512` frames `FFT` com packet indices `512 .. 1023`
3. reinicio imediato na proxima janela

Como `DIAG_BFPEXP_HOLD_FRAMES = 1`, nao existe hold prolongado. O stream fica:

```text
BFPEXP[0], FFT[512], FFT[513], ..., FFT[1023], BFPEXP[0], ...
```

## Palavras de 32 bits esperadas

O packing do RTL segue o contrato do host:

- bits `[31:22]`: packet index
- bits `[21:20]`: tag
- bits `[19:18]`: reserved, sempre `0`
- bits `[17:0]`: payload signed em complemento de dois

Palavras esperadas:

| Tipo | Packet index | Canal esquerdo | Canal direito | Tag | Payload decodificado |
| --- | --- | --- | --- | --- | --- |
| BFPEXP | `0` | `0x0013FFEE` | `0x0013FFEE` | `1` | `-18` em ambos |
| FFT bin 0 | `512` | `0x80215555` | `0x80235555` | `2` | `87381` no left, `-43691` no right |
| FFT bin 1 | `513` | `0x80615555` | `0x80635555` | `2` | `87381` no left, `-43691` no right |

Observacoes:

- o frame `BFPEXP` usa o mesmo valor nos dois canais;
- o frame `FFT` usa left/right diferentes de proposito para facilitar detectar troca de canais;
- o mesmo packet index deve aparecer nos dois canais de cada frame;
- cada incremento de bin soma `0x00400000` na palavra hexadecimal, o que facilita enxergar o numero do bin em debug bruto;
- os bits reservados `[19:18]` devem permanecer em zero.

## Comportamento esperado no software

### Comandos prontos no host

No Raspberry Pi, entre na pasta do receiver antes de rodar os testes:

```bash
cd submodules/ACES-RPi-interface/rpi3b_i2s_fft
```

Captura tagged minima para validar o contrato deste topo:

```bash
.venv/bin/python analyzer_from_fpga_fft.py -r 48000 \
    --frame-bins 512 --useful-bins 256 \
    --use-i2s-tags --bfpexp-hold-pairs 1 \
    --packet-index-shift 22 --packet-index-bits 10 --fft-packet-index-base 512 \
    --tag-shift 20 --tag-mask 0x3 --payload-bits 18 \
    --tag-idle 0 --tag-bfpexp 1 --tag-fft 2
```

Se quiser aceitar FFT mesmo quando o host nao tiver observado um `BFPEXP` antes do
inicio da captura, rode a variante relaxada:

```bash
.venv/bin/python analyzer_from_fpga_fft.py -r 48000 \
    --frame-bins 512 --useful-bins 256 \
    --use-i2s-tags --bfpexp-hold-pairs 1 \
    --packet-index-shift 22 --packet-index-bits 10 --fft-packet-index-base 512 \
    --tag-shift 20 --tag-mask 0x3 --payload-bits 18 \
    --tag-idle 0 --tag-bfpexp 1 --tag-fft 2 \
    --allow-fft-without-bfpexp
```

Para gerar automaticamente os arquivos `.jsonl` e o `scenario_summary.tsv` usados
nas secoes abaixo:

```bash
./run_channel_debug_matrix.sh \
    --seconds 8 \
    --frame-bins 512 --useful-bins 256 \
    --bfpexp-hold-pairs 1 \
    --packet-index-shift 22 --packet-index-bits 10 --fft-packet-index-base 512 \
    --tag-shift 20 --tag-mask 0x3 --payload-bits 18 \
    --extra-tag-shifts 21
```

Se houver uma GPIO de apoio para marcar `BFPEXP`, acrescente por exemplo:

```bash
./run_channel_debug_matrix.sh \
    --seconds 8 \
    --frame-bins 512 --useful-bins 256 \
    --bfpexp-hold-pairs 1 \
    --packet-index-shift 22 --packet-index-bits 10 --fft-packet-index-base 512 \
    --tag-shift 20 --tag-mask 0x3 --payload-bits 18 \
    --bfpexp-flag-line 23 \
    --extra-tag-shifts 21
```

### 1. Nivel bruto de palavra

Com o comando tagged acima, o software deve decodificar:

- `BFPEXP` sempre como `(-18, -18)`
- `FFT` sempre como `(87381, -43691)`

Se aparecer qualquer outro payload em regime permanente, o erro ja nao esta na FFT:
esta no transporte, no alinhamento, ou na decodificacao.

### 2. Nivel de janela logica

Com os comandos acima usando `--frame-bins 512`, o receptor tagged deve montar
frames com:

- um `BFPEXP` antes da janela,
- exatamente `512` pares `FFT`,
- todos os `512` pares identicos.

Se o receptor tagged nao conseguir montar uma janela completa com esse topo,
o problema esta na serializacao tagged ou na interpretacao do host, nao no caminho
de audio/FFT original.

## Como interpretar `scenario_summary.tsv`

O script `run_channel_debug_matrix.sh` gera tres cenarios por default:

1. `strict_tags_shift20`
2. `relaxed_tags_shift20`
3. `relaxed_tags_shift21`

Para este topo de diagnostico, o esperado e:

- `strict_tags_shift20`: deve ser o cenario bom
- `relaxed_tags_shift20`: pode ficar parecido com o strict, mas nao deve ser melhor
- `relaxed_tags_shift21`: deve piorar claramente

Leitura dos campos mais importantes:

### `reserved_nonzero_words`

Esperado: `0`.

Interpretacao:

- `0`: padding e alinhamento de bit estao consistentes com o contrato `{packet_index, tag, 2'd0, payload}`
- `> 0`: algum bit que deveria estar em `[19:18] = 0` esta sendo visto como nao zero

Se esse contador cresce de forma persistente, suspeite primeiro de:

- `tag_shift` errado,
- `packet_index_shift` errado,
- erro de alinhamento de bit,
- erro de temporizacao `WS`/`SCK`,
- captura fora do formato Philips I2S esperado.

### `tag_mismatch`

Esperado: muito proximo de `0` depois do startup.

Interpretacao:

- `left` e `right` estao chegando com tags diferentes no mesmo par;
- isso normalmente aponta para erro de enquadramento entre canais, nao para erro do payload em si.

Suspeitas principais:

- troca de borda de amostragem,
- `WS` mudando na hora errada,
- perda de alinhamento entre left/right,
- um canal sendo montado com deslocamento diferente do outro.

### `packet_index_mismatch`

Esperado: `0`.

Interpretacao:

- left e right chegaram com o mesmo `tag`, mas com packet indices diferentes;
- ou o `tag` esta em desacordo com a faixa do packet index, por exemplo `BFPEXP >= 512` ou `FFT < 512`.

Suspeitas principais:

- perda de um word em apenas um dos canais,
- erro de alinhamento entre left/right,
- `packet_index_shift` incorreto,
- corrupcao dos bits mais altos do word.

### `other`

Esperado: `0` ou apenas alguns eventos de captura parcial no comeco/fim.

Interpretacao:

- os dois canais concordam na tag, mas a tag nao e `idle`, `bfpexp` ou `fft`.

Suspeitas principais:

- `tag_shift` errado,
- `packet_index_shift` errado,
- `tag_mask` errado,
- bits altos corrompidos.

### `idle`

Esperado: baixo apos reset.

Este topo alimenta o adapter continuamente. Depois do startup inicial, o stream
deveria ficar praticamente so em `BFPEXP` e `FFT`.

Se `idle` dominar a captura:

- o gerador nao esta aceitando amostras,
- o clock/reset da placa nao estao como esperado,
- ou a captura do host esta acontecendo fora da janela em que a FPGA esta transmitindo.

### `fft_run_lengths` e `top_fft_run_lengths`

Esperado: execucoes longas de aproximadamente `512`.

Interpretacao:

- cada run `FFT` representa uma janela logica entre dois `BFPEXP`;
- o valor dominante deve ser `512`, porque este topo emite `512` bins por janela.

Excecoes normais:

- a primeira run pode vir truncada se a captura comecou no meio de uma janela;
- a ultima run pode vir truncada se a captura terminou no meio de uma janela.

Se as runs dominantes ficarem muito menores que `512`, suspeite:

- `BFPEXP` extra no meio da janela,
- perda de frames `FFT`,
- erro no `fft_last_i`,
- ou decodificacao do host quebrando a run por falso `idle`, `other`, `tag_mismatch` ou `packet_index_mismatch`.

## Como interpretar o `preview` dos arquivos `.jsonl`

Nos `preview` por chunk, procure estes pares:

```json
{"kind":"bfpexp", "left":{"hex":"0x0013FFEE", "packet_index":0, ...}, "right":{"hex":"0x0013FFEE", "packet_index":0, ...}}
{"kind":"fft",    "left":{"hex":"0x80215555", "packet_index":512, ...}, "right":{"hex":"0x80235555", "packet_index":512, ...}}
```

Se o topo estiver correto:

- `kind` deve alternar entre `bfpexp` e longas sequencias de `fft`,
- `left.hex` e `right.hex` devem bater com a tabela acima,
- `left.packet_index` e `right.packet_index` devem ser iguais,
- `reserved_nonzero` deve ser `false` nos dois canais.

## Diagnostico rapido por sintoma

| Sintoma | Hipotese mais forte |
| --- | --- |
| `strict_tags_shift20` ruim e `shift21` melhor | deslocamento de tag/alinhamento de bit |
| `reserved_nonzero_words` alto | padding ou alinhamento bruto do frame I2S |
| `tag_mismatch` alto | left/right desalinhados, erro de `WS` |
| `packet_index_mismatch` alto | perda de pacote em um canal ou leitura errada dos bits altos |
| tags corretas mas payload errado | problema no dado bruto, ordem de bits, sinal, ou troca left/right |
| runs `FFT` curtas demais | a janela logica esta sendo quebrada no transporte |
| `idle` dominante | fonte nao esta transmitindo continuamente ou captura iniciou fora do regime |

## Simulacao

```bash
sim/manifest/scripts/run_questa.sh top_level_i2s_fft_tx_diag mock
```

O testbench verifica o packing bruto esperado e garante que o stream gerado
bate com o contrato documentado aqui, incluindo packet index, tags, bits
reservados e igualdade left/right por frame.

## Compilacao no Quartus

O repositorio inclui `quartus/top_level_i2s_fft_tx_diag_sources.tcl` com as fontes
necessarias desse topo de diagnostico.

Para compilar usando o mesmo pinout do `top_level_test`, basta reaproveitar o
projeto Quartus atual e trocar duas atribuicoes:

1. `TOP_LEVEL_ENTITY` -> `top_level_i2s_fft_tx_diag`
2. `SOURCE_TCL_SCRIPT_FILE` -> `top_level_i2s_fft_tx_diag_sources.tcl`

Como o port map foi mantido, nao e necessario remapear os pinos do host.
