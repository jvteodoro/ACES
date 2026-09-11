# Mapeamento físico da DE10-Lite para o ACES

Este documento define o contrato elétrico do top-level
`de10lite_audio_fft_top` para a placa Terasic DE10-Lite, dispositivo
`10M50DAF484C7G`.

O mapeamento de GPIO foi conferido contra o `DE10_LITE_Golden_Top.qsf` do
SystemCD local da placa. Todos os sinais utilizam `3.3-V LVTTL`.

## Sinais utilizados pelo ACES

| Sinal lógico | Direção na FPGA | Pino MAX 10 | Função |
|---|---:|---|---|
| `MAX10_CLK1_50` | entrada | `PIN_P11` | clock de 50 MHz da placa |
| `KEY[0]` | entrada | `PIN_B8` | reset ativo em nível baixo |
| `KEY[1]` | entrada | `PIN_A7` | reservado para expansão/debug |
| `SW[0]` | entrada | `PIN_C10` | seleção do canal L/R do microfone |
| `GPIO[0]` | entrada | `PIN_V10` | I2S `SD` do microfone |
| `GPIO[1]` | saída | `PIN_W10` | I2S `SCK` gerado pela FPGA |
| `GPIO[2]` | saída | `PIN_V9` | I2S `WS/LRCLK` gerado pela FPGA |
| `GPIO[3]` | saída | `PIN_W9` | seleção L/R do microfone |
| `GPIO[4]` | saída | `PIN_V8` | clock da saída I2S FFT opcional |
| `GPIO[5]` | saída | `PIN_W8` | WS da saída I2S FFT opcional |
| `GPIO[6]` | saída | `PIN_V7` | dados da saída I2S FFT opcional |
| `GPIO[7]` | saída | `PIN_W7` | `mfcc_valid` |
| `GPIO[8]` | saída | `PIN_W6` | `feature_frame_done` |

`GPIO[4..6]` permanecem disponíveis para diagnóstico e exportação I2S, mas
não são necessários para o processamento local da FFT/MFCC. O processamento
principal não depende de um canal serial externo.

## GPIOs restantes

Os pinos abaixo são atribuídos no QSF conforme o Golden Top da DE10-Lite para
eliminar pinos sem localização física. No RTL atual eles permanecem em alta
impedância (`GPIO[35:9] = 'z`) e não devem ser conectados a sinais externos
durante o bring-up.

| GPIO | Pino MAX 10 | Estado atual |
|---:|---|---|
| 9 | `PIN_V5` | reservado, alta impedância |
| 10 | `PIN_W5` | reservado, alta impedância |
| 11 | `PIN_AA15` | reservado, alta impedância |
| 12 | `PIN_AA14` | reservado, alta impedância |
| 13 | `PIN_W13` | reservado, alta impedância |
| 14 | `PIN_W12` | reservado, alta impedância |
| 15 | `PIN_AB13` | reservado, alta impedância |
| 16 | `PIN_AB12` | reservado, alta impedância |
| 17 | `PIN_Y11` | reservado, alta impedância |
| 18 | `PIN_AB11` | reservado, alta impedância |
| 19 | `PIN_W11` | reservado, alta impedância |
| 20 | `PIN_AB10` | reservado, alta impedância |
| 21 | `PIN_AA10` | reservado, alta impedância |
| 22 | `PIN_AA9` | reservado, alta impedância |
| 23 | `PIN_Y8` | reservado, alta impedância |
| 24 | `PIN_AA8` | reservado, alta impedância |
| 25 | `PIN_Y7` | reservado, alta impedância |
| 26 | `PIN_AA7` | reservado, alta impedância |
| 27 | `PIN_Y6` | reservado, alta impedância |
| 28 | `PIN_AA6` | reservado, alta impedância |
| 29 | `PIN_Y5` | reservado, alta impedância |
| 30 | `PIN_AA5` | reservado, alta impedância |
| 31 | `PIN_Y4` | reservado, alta impedância |
| 32 | `PIN_AB3` | reservado, alta impedância |
| 33 | `PIN_Y3` | reservado, alta impedância |
| 34 | `PIN_AB2` | reservado, alta impedância |
| 35 | `PIN_AA2` | reservado, alta impedância |

## LEDs e displays

O estado operacional é exposto nos LEDs e o último valor MFCC é exibido nos
três displays usados pelo projeto:

| Grupo | Pinos |
|---|---|
| `LEDR[0..9]` | `A8, A9, A10, B10, D13, C13, E14, D14, A11, B11` |
| `HEX0[0..7]` | `C14, E15, C15, C16, E16, D17, C17, D15` |
| `HEX1[0..7]` | `C18, D18, E18, B16, A17, A18, B17, A16` |
| `HEX2[0..7]` | `B20, A20, B19, A21, B21, C22, B22, A19` |

## Saída VGA do dashboard

O dashboard usa saída RGB de 4 bits por componente, com sincronismos ativos em
nível baixo. O pixel clock interno é 25 MHz, derivado do clock de 50 MHz.

| Sinal | Pino | Sinal | Pino |
|---|---|---|---|
| `VGA_HS` | `PIN_N3` | `VGA_VS` | `PIN_N1` |
| `VGA_R[0..3]` | `AA1, V1, Y2, Y1` | `VGA_G[0..3]` | `W1, T2, R2, R1` |
| `VGA_B[0..3]` | `P1, T1, P4, N2` | | |

Todos os sinais VGA usam `3.3-V LVTTL`. O formato é 640×480 com timing
compatível com 60 Hz. O contrato de dados e a estratégia de snapshots estão
descritos em [`docs/vga_dashboard.md`](vga_dashboard.md).

## Regras elétricas e de validação

1. O microfone deve compartilhar GND com a DE10-Lite e operar em nível lógico
   compatível com 3,3 V.
2. `GPIO[0]` é entrada; não aplicar sinal de saída nesse pino.
3. `GPIO[1..8]` são dirigidos pela FPGA; não conectá-los a saídas ativas
   externas sem garantir que não haverá disputa de barramento.
4. `KEY[0]` é reset ativo-baixo; manter o botão liberado durante a operação.
5. Antes do teste acústico, verificar no osciloscópio `GPIO[1]` e `GPIO[2]`
   e confirmar a frequência efetiva do I2S.
6. O pinout está completo no QSF, mas o fechamento de timing e o teste físico
   de ruído ainda são requisitos de aceitação do produto.

## Fonte do mapa

O mapa foi extraído do arquivo oficial do SystemCD:

`C:\Users\jvcte\DE10Lite\DE10-Lite_v.2.2.0_SystemCD\Demonstrations\Golden_Top\DE10_LITE_Golden_Top.qsf`

As atribuições do projeto estão em
`quartus/de10lite_audio_fft.qsf`.
