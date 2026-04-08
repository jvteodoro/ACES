# Top-Level Tagged-I2S com FFT de `sine_1k`

## Objetivo

`top_level_i2s_fft_tx_sine_1k` reaproveita a camada de transporte tagged-I2S do
projeto e substitui o pipeline completo de audio/FFT por uma LUT fixa com a
transformada de um seno de `1 kHz`.

O objetivo e separar duas perguntas:

1. o transporte tagged-I2S esta entregando uma janela valida ao Raspberry Pi?
2. com bins corretos e deterministas, o espectrograma do host aparece como esperado?

## Fonte dos bins

Os bins sao gerados por:

```bash
python3 utils/generate_sine_1k_transport_assets.py
```

Esse script:

- usa o mesmo `example_0 = sine_1k` do gerador oficial do projeto,
- reaplica o modelo Python do loopback I2S usado em `top_level_test`,
- calcula a FFT de `512` pontos com `Fs = 48828 Hz`,
- quantiza os bins complexos para `18 bits` com `BFPEXP = 0`,
- escreve a LUT do FPGA em `rtl/top/top_level_i2s_fft_tx_sine_1k_lut.svh`,
- escreve a referencia do host em `submodules/ACES-RPi-interface/rpi3b_i2s_fft/sine_1k_reference.py`.

Referencia atual do pico:

- `peak_bin = 10`
- `peak_hz = 953.671875`

Isso bate com a expectativa documentada do `sine_1k` no restante do repositorio.

## Pinout reutilizado

O topo exporta o stream I2S nos mesmos grupos de pinos usados pelo
`top_level_test`:

- `GPIO_1_D21 / D23 / D25`
- `GPIO_1_D27 / D29 / D31`
- `GPIO_1_D30 / D32 / D34`

Tambem espelha o stream em:

- `GPIO_0_D30 / D32 / D34`

para facilitar debug rapido de bancada.

## Compilacao no Quartus

Para usar este topo no projeto raiz, basta reaproveitar o mesmo `.qsf` do
`top_level_test` e trocar:

1. `TOP_LEVEL_ENTITY` para `top_level_i2s_fft_tx_sine_1k`
2. `SOURCE_TCL_SCRIPT_FILE` para `top_level_i2s_fft_tx_sine_1k_sources.tcl`

## Teste offline no Raspberry Pi

Se a ideia for validar primeiro a visualizacao, sem depender da FPGA, gere um
`fft.npy` artificial diretamente no Pi:

```bash
cd submodules/ACES-RPi-interface/rpi3b_i2s_fft
python3 sine_1k_reference.py --frame-count 64
python3 plotFFT.py --spectrogram --fft-file fft.npy --rate 48828 --frame-bins 512 --max-freq 5000 --backend Agg
```

O esperado e:

- uma linha horizontal estavel no espectrograma,
- pico dominante perto de `953.67 Hz`,
- energia secundaria nos bins vizinhos por vazamento espectral.

## Teste com a FPGA

Para capturar o stream tagged real no host:

```bash
cd submodules/ACES-RPi-interface/rpi3b_i2s_fft
.venv/bin/python analyzer_from_fpga_fft.py \
  --strict-sync \
  --rate 48828 \
  --frame-bins 512 \
  --useful-bins 256 \
  --packet-index-shift 22 \
  --packet-index-bits 10 \
  --fft-packet-index-base 512 \
  --tag-shift 20 \
  --tag-mask 0x3 \
  --payload-bits 18 \
  --tag-idle 0 \
  --tag-bfpexp 1 \
  --tag-fft 2
```

Como o topo usa `BFPEXP = 0`, a magnitude exibida no host deve vir diretamente
dos bins quantizados da LUT.
