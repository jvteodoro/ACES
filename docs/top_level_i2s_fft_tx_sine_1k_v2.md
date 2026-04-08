# Top-Level Tagged-I2S com FFT de `sine_1k` e `BFPEXP` forcado

## Objetivo

`top_level_i2s_fft_tx_sine_1k_v2` reutiliza a mesma LUT deterministica do
`top_level_i2s_fft_tx_sine_1k`, mas agora transmite os bins com
`DIAG_TEST_BFPEXP = 8`.

Para manter o espectro corrigido no host equivalente ao caso base, o topo:

- aplica `>>> DIAG_TEST_BFPEXP` aos bins crus antes do transporte,
- envia `BFPEXP = 8` no preambulo tagged-I2S.

Com isso, um host que aplica `bfpexp` corretamente deve reconstruir
praticamente o mesmo espectro do caso `BFPEXP = 0`.

## O que este teste mostra

- se o Raspberry Pi aplicar `bfpexp`, o pico em `~953.67 Hz` deve continuar
  no mesmo lugar e com forma muito parecida ao caso base;
- se o Raspberry Pi ignorar `bfpexp`, a energia recebida tende a aparecer
  cerca de `48 dB` abaixo do caso base, porque os bins crus foram divididos por
  `256`.

## Compilacao no Quartus

No projeto raiz, troque:

1. `TOP_LEVEL_ENTITY` para `top_level_i2s_fft_tx_sine_1k_v2`
2. `SOURCE_TCL_SCRIPT_FILE` para `top_level_i2s_fft_tx_sine_1k_v2_sources.tcl`

## Observacao

Se quiser aumentar a agressividade do teste depois, basta alterar o parametro
`DIAG_TEST_BFPEXP` no topo `v2`. O valor default `8` foi escolhido para
forcar um teste bem mais agressivo do tratamento de expoente no host.
