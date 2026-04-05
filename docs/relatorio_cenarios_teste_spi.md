# Cenários de Teste dos Módulos SPI

Este documento reúne cenários de teste prontos para uso em relatório técnico
sobre o subsistema SPI do projeto ACES. O conteúdo foi elaborado a partir dos
testbenches `tb_spi_fft_tx_adapter`, `tb_fft_tx_spi_link`,
`tb_top_level_spi_fft_tx_diag` e `tb_top_level_test`, com base nas simulações
executadas e aprovadas em 5 de abril de 2026.

Os resultados simulados observados foram:

- `tb_spi_fft_tx_adapter PASSED`
- `tb_fft_tx_spi_link PASSED`
- `tb_top_level_spi_fft_tx_diag PASSED`
- `tb_top_level_test PASSED no fluxo mock com smoke/protocolo do stream TX`

## Cenário de Teste 43 – Validação Unitária do Empacotamento e da Serialização SPI

Este cenário verifica, em nível unitário, o comportamento funcional do módulo
`spi_fft_tx_adapter`. O objetivo é confirmar que o adaptador converte o fluxo de
bins da FFT em transações SPI válidas, preservando o empacotamento tagged de
32 bits, a repetição do BFPEXP e a ordenação correta dos bins em múltiplas
janelas.

O testbench injeta duas janelas FFT com expoentes distintos, atua como mestre
SPI em modo 0 e reconstrói as palavras a partir dos bits observados em
`spi_miso_o`. Além da verificação da sequência transmitida, o cenário também
checa coerência entre `fifo_level_o`, `fifo_empty_o`, `fifo_full_o`,
`window_ready_o`, `spi_active_o` e ausência de `overflow_o`.

**Tabela 43 – Descrição e Resultados Simulados do Cenário de Teste 43**

| `rst` / condição inicial | `fft_valid_i`, `fft_real_i`, `fft_imag_i`, `fft_last_i`, `bfpexp_i` | `spi_cs_n_i` / `spi_sclk_i` | `window_ready_o` / `spi_active_o` esperados | `spi_miso_o` / palavras decodificadas esperadas | `fifo_level_o` / `overflow_o` esperados | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reset ativo e nenhuma janela FFT armazenada | Nenhum bin aplicado | Transação SPI iniciada logo após o reset | `window_ready_o = 0` antes da leitura; `spi_active_o = 1` apenas durante a transação | Par `IDLE` com duas palavras nulas tagged | FIFO permanece vazia; `overflow_o = 0` | Sim | Nenhuma não conformidade observada. O bench decodificou corretamente o par `IDLE`, comprovando resposta segura antes de existir janela válida. |
| Sistema fora de reset | Quatro bins: `(11,-12)`, `(13,-14)`, `(15,-16)`, `(17,-18)` com `bfpexp = 5`, sendo o último com `fft_last_i = 1` | Leitura SPI iniciada após `window_ready_o = 1` | `window_ready_o` sobe ao completar a janela; `spi_active_o` desce ao final da transação | Três pares `BFPEXP` seguidos por quatro pares `FFT`, todos com tags e payloads corretos | FIFO acumula ao menos uma janela completa; `overflow_o = 0` | Sim | Nenhuma não conformidade observada. A reconstrução little-endian das palavras conferiu integralmente com os valores esperados. |
| Sistema em operação contínua | Segunda janela com quatro bins: `(-21,22)`, `(-23,24)`, `(-25,26)`, `(-27,28)` com `bfpexp = -2`, último bin com `fft_last_i = 1` | Nova transação SPI após nova elevação de `window_ready_o` | `window_ready_o` volta a subir somente após a nova janela estar completa | Três pares `BFPEXP` com payload `-2`, seguidos por quatro pares `FFT` na ordem de entrada | FIFO esvazia ao final da segunda transação; `overflow_o = 0` | Sim | Nenhuma não conformidade observada. O cenário confirmou que a mudança de janela e de BFPEXP não corrompe o enquadramento SPI. |
| Fim do teste | Nenhum novo bin | Nenhuma transação adicional | `spi_active_o = 0` ao final | Nenhum frame residual inesperado | `fifo_level_o = 0`; `fifo_empty_o = 1`; `fifo_full_o = 0`; `overflow_o = 0` | Sim | Nenhuma não conformidade observada. O teste finalizou com FIFO vazia, sem saturação e sem atividade SPI residual. |

**Figura sugerida após a Tabela 43**

Inserir captura de waveform mostrando:

- leitura `IDLE` antes de `window_ready_o`;
- primeira transação com repetição de `BFPEXP`;
- transição entre os pares `BFPEXP` e `FFT`;
- desativação de `spi_active_o` ao final da janela.

## Cenário de Teste 44 – Integração entre FIFO de Ponte e Adaptador SPI

Este cenário valida a integração entre `fft_tx_bridge_fifo` e
`spi_fft_tx_adapter`, modelando a condição real em que os bins da FFT são
produzidos em rajada e o escoamento para o host ocorre em ritmo diferente. O
objetivo principal é comprovar o desacoplamento temporal entre produtor e
consumidor sem perda de ordenação, sem duplicação e sem overflow.

O testbench injeta duas janelas consecutivas diretamente na FIFO externa,
conecta a saída show-ahead dessa FIFO à entrada do adaptador e reconstrói a
saída SPI para confirmar que a sequência transmitida continua idêntica à
esperada. Além disso, monitora a coerência do handshake `valid/ready` por meio
de `bridge_pop_i`.

**Tabela 44 – Descrição e Resultados Simulados do Cenário de Teste 44**

| `push_i`, `fft_real_i`, `fft_imag_i`, `fft_last_i`, `bfpexp_i` | `spi_cs_n_i` / `spi_sclk_i` | `fifo_valid_o` / `adapter_ready_o` / `bridge_pop_i` esperados | `fifo_level_o` / `adapter_fifo_level_o` esperados | `window_ready_o` / `spi_active_o` esperados | `spi_miso_o` / palavras decodificadas esperadas | `fifo_overflow_o` / `adapter_overflow_o` esperados | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Seis bins injetados em sequência formando duas janelas: `(3,4)`, `(5,6)`, `(7,8,last)` com `bfpexp=7`; depois `(-9,-10)`, `(-11,-12)`, `(-13,-14,last)` com `bfpexp=-1` | Nenhuma leitura SPI durante a fase inicial de enchimento | `bridge_pop_i` só pode ocorrer quando `fifo_valid_o = 1` e `adapter_ready_o = 1` | A FIFO externa deve acumular ocupação acima de 1 durante a rajada | `window_ready_o` ainda não precisa drenar imediatamente a primeira janela | Nenhuma palavra inválida deve surgir antes da leitura | Ambos os overflows devem permanecer em zero | Sim | Nenhuma não conformidade observada. O handshake `bridge_pop_i == fifo_valid_o && adapter_ready_o` permaneceu coerente durante todo o ensaio. |
| Primeira janela já acumulada | Primeira transação SPI iniciada pelo bench | `bridge_pop_i` acompanha o escoamento válido da FIFO externa para o adaptador | A ocupação diminui à medida que a janela é drenada | `window_ready_o` alto antes da leitura e `spi_active_o` alto apenas durante a transação | Dois pares `BFPEXP` com expoente `7`, seguidos dos pares FFT `(3,4)`, `(5,6)`, `(7,8)` | `fifo_overflow_o = 0`; `adapter_overflow_o = 0` | Sim | Nenhuma não conformidade observada. O caminho integrado preservou o mesmo protocolo visto no teste unitário do adaptador. |
| Segunda janela pendente na cadeia | Segunda transação SPI após novo `window_ready_o` | O escoamento deve continuar sem leituras espúrias | A FIFO externa e a FIFO interna do adaptador devem esvaziar ao final da segunda janela | `spi_active_o` volta a zero ao fim da transação | Dois pares `BFPEXP` com expoente `-1`, seguidos dos pares FFT `(-9,-10)`, `(-11,-12)`, `(-13,-14)` | `fifo_overflow_o = 0`; `adapter_overflow_o = 0` | Sim | Nenhuma não conformidade observada. A troca entre as duas janelas não introduziu desalinhamento nem mistura de payloads. |
| Finalização | Nenhum novo push | Nenhuma transação adicional | Sem pops residuais | Ambas as FIFOs devem estar vazias | Nenhum dado residual deve aparecer na saída | `fifo_empty_o = 1`; `adapter_fifo_empty_o = 1`; overflows em zero | Sim | Nenhuma não conformidade observada. O cenário terminou com a cadeia totalmente drenada e sem saturação. |

**Figura sugerida após a Tabela 44**

Inserir captura de waveform mostrando:

- crescimento de `fifo_level_o` durante a rajada;
- ativação condicionada de `bridge_pop_i`;
- leitura SPI da primeira janela;
- esvaziamento completo das duas FIFOs ao final.

## Cenário de Teste 45 – Validação do Top de Diagnóstico SPI

Este cenário valida `top_level_spi_fft_tx_diag`, que substitui temporariamente o
datapath real por um gerador determinístico de bins FFT. O objetivo é comprovar
que o topo de diagnóstico expõe nos pinos de borda o mesmo contrato SPI do
adaptador, tornando possível depurar cabeamento, decodificação do host e sinais
de observabilidade sem depender do caminho completo de aquisição e FFT.

O testbench aplica reset pelo pino `gpio_1_d1`, atua como mestre SPI pelos
pinos `gpio_1_d27` e `gpio_1_d29`, observa os dados em `gpio_1_d31` e usa
`gpio_1_d25` como indicação de janela pronta. Ao final, ainda confirma que o
gerador produziu pelo menos duas janelas e que não houve overflow latched.

**Tabela 45 – Descrição e Resultados Simulados do Cenário de Teste 45**

| `gpio_1_d1` / reset | Parâmetros e estímulo diagnóstico | `gpio_1_d29` / `gpio_1_d27` | `gpio_1_d25` esperado | `gpio_1_d31` / palavras decodificadas esperadas | `diag_window_count_r` / `diag_overflow_latched_r` esperados | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Reset inicialmente ativo e depois liberado | `DIAG_WINDOW_BINS = 4`, `DIAG_BFPEXP_HOLD_FRAMES = 1`, valores fixos `real = 18'sh15555`, `imag = 18'sh0AAAB`, `bfpexp = 8'sh12` | Sem transação SPI antes da janela | `gpio_1_d25` deve subir quando a primeira janela sintética estiver pronta | Nenhum payload inválido antes da leitura | Sem overflow; contagem de janelas cresce com o tempo | Sim | Nenhuma não conformidade observada. O topo de diagnóstico sinalizou disponibilidade de janela de forma consistente após a saída do reset. |
| Primeira janela pronta | Mesmo padrão fixo para todos os bins | Primeira transação SPI comandada pelo bench | `gpio_1_d25` já estava ativo antes da leitura | Um par `BFPEXP` com payload estendido `18`, seguido por quatro pares FFT com os valores constantes de real e imag | `diag_overflow_latched_r = 0` | Sim | Nenhuma não conformidade observada. A saída nos pinos refletiu exatamente o padrão programado no topo. |
| Continuidade do gerador diagnóstico | Geração automática de nova janela após aceitar bins | Segunda transação SPI após nova elevação de `gpio_1_d25` | `gpio_1_d25` deve voltar a sinalizar nova janela completa | Repetição da mesma sequência determinística da primeira janela | `diag_window_count_r >= 2`; `diag_overflow_latched_r = 0` | Sim | Nenhuma não conformidade observada. O cenário confirmou repetibilidade entre janelas consecutivas e ausência de saturação do caminho interno. |

**Figura sugerida após a Tabela 45**

Inserir captura de waveform mostrando:

- `gpio_1_d25` subindo antes da transação;
- `gpio_1_d29` e `gpio_1_d27` durante a leitura SPI;
- reconstrução do par BFPEXP e dos quatro pares FFT;
- evolução de `diag_window_count_r`.

## Cenário de Teste 46 – Integração do Caminho SPI no Top-Level Principal

Este cenário valida o fluxo SPI já integrado ao `top_level_test` no modo mock.
O objetivo é comprovar que o topo principal encaminha corretamente os sinais do
subsistema ACES para os pinos físicos de SPI, preservando o contrato de janela
pronta, a reflexão de `MISO` em `GPIO_1_D31` e o enquadramento do fluxo serial
esperado pelo bench.

O testbench injeta o fluxo de áudio pela infraestrutura de estímulo mock, observa
os bins FFT produzidos pelo sistema, monta uma fila de frames esperados e drena
automaticamente a janela serial sempre que `gpio_1_d25` sobe. Além disso, ele
verifica o número de bins FFT, a ausência de overflow no caminho SPI e a
coerência entre o sinal interno e o pino exportado.

**Tabela 46 – Descrição e Resultados Simulados do Cenário de Teste 46**

| Configuração do top e estímulo | Entradas SPI do host (`gpio_1_d29`, `gpio_1_d27`) | Sinais internos relevantes | Saídas físicas esperadas (`gpio_1_d25`, `gpio_1_d31`) | Saídas funcionais esperadas do caminho SPI | `tx_overflow_o` / contadores esperados | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `top_level_test` em fluxo mock, com gerador de estímulo ativo e caminho SPI conectado ao ACES | O bench controla `tb_spi_cs_n_drive` e `tb_spi_sclk_drive`, refletidos em `gpio_1_d29` e `gpio_1_d27` | `dut.tx_spi_window_ready_o` e `dut.tx_spi_miso_o` | `gpio_1_d25` deve refletir exatamente `dut.tx_spi_window_ready_o`; `gpio_1_d31` deve refletir exatamente `dut.tx_spi_miso_o` | O protocolo serial só deve ser drenado quando a janela estiver pronta | `tx_overflow_o = 0` | Sim | Nenhuma não conformidade observada no caminho SPI. O bench contém asserts dedicadas para a reflexão dos pinos e ambas passaram. |
| Janela FFT completa produzida pelo fluxo mock | Leitura SPI iniciada na borda de subida de `gpio_1_d25` | `dut.fft_tx_valid_o`, `dut.bfpexp_o`, `dut.u_aces.u_spi_fft_tx_adapter.fft_ready_o` | `gpio_1_d25` dispara a drenagem da janela; `gpio_1_d31` fornece o stream serial correspondente | A fila de frames esperados deve conter `BFPEXP_HOLD_FRAMES + FFT_LENGTH` pares, com BFPEXP no início e bins FFT na sequência | `serial_frames = 513`, sem `extra_serial` | Sim | Nenhuma não conformidade observada. O bench drenou a janela inteira e confirmou o protocolo do stream TX no topo principal. |
| Execução completa do exemplo mock | O host conclui a transação SPI e retorna `CS_N` ao alto | `dut.fft_tx_valid_o`, `dut.fft_tx_last_o` e indicadores de término da janela | `gpio_1_d25` deve voltar ao comportamento esperado de handshake por janela | O número de bins FFT observados deve coincidir com o comprimento da FFT do caso mock | `fft_bins = 512`, `extra_fft = 0`, `tx_overflow_o = 0` | Sim | Nenhuma não conformidade observada para o caminho SPI. A simulação terminou com `PASSED`; houve apenas três warnings conhecidos em `aces_audio_to_fft_pipeline.sv`, sem impacto no protocolo SPI. |

**Figura sugerida após a Tabela 46**

Inserir captura de waveform mostrando:

- reflexão de `tx_spi_window_ready_o` em `gpio_1_d25`;
- reflexão de `tx_spi_miso_o` em `gpio_1_d31`;
- disparo automático de `spi_drain_expected_window()` na elevação de `gpio_1_d25`;
- sequência inicial de frames esperados na leitura do topo.

## Observação Final para o Relatório

Se o relatório exigir correlação explícita entre texto, tabela e simulação, uma
boa estratégia é posicionar após cada tabela pelo menos uma figura contendo:

- os sinais de entrada aplicados no cenário;
- os sinais de saída observados;
- uma anotação visual do instante em que a condição esperada foi satisfeita.

No caso dos cenários SPI, as figuras mais úteis tendem a incluir:

- `window_ready_o` ou `gpio_1_d25`,
- `spi_active_o` ou `gpio_1_d29`,
- `spi_sclk_i` ou `gpio_1_d27`,
- `spi_miso_o` ou `gpio_1_d31`,
- `fifo_level_o`,
- `overflow_o`,
- e, quando pertinente, `active_pair_kind_r` e `complete_windows_r`.
