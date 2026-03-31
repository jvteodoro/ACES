# Testbench Report Tables

Este documento organiza os testbenches atuais do projeto em um formato compatível com relatório técnico. Cada seção descreve o objetivo do cenário em até dois parágrafos curtos e apresenta uma tabela no estilo “Entradas / Saídas Esperadas / Resultado Simulado OK? / Análise de Não Conformidades”.

O campo **Resultado Simulado OK?** foi escrito de forma reutilizável para relatório: quando o testbench termina com a mensagem `PASSED` e sem disparar `assert`/`$error`, o cenário deve ser marcado como **Sim**. Caso contrário, a coluna **Análise de Não Conformidades** deve receber a divergência observada na execução correspondente.

## 4.3.1 Cenário de Teste 1 — `tb_hexa7seg`

Este cenário valida o decodificador hexadecimal de 7 segmentos para todos os 16 valores possíveis de entrada. O objetivo é garantir que a codificação exibida no display corresponda exatamente à tabela esperada pelo hardware.

O testbench é puramente combinacional e cobre a tabela completa `0x0` a `0xF`, sendo adequado para compor a parte do relatório referente à conformidade funcional do bloco de exibição. 

**Tabela 1 – Descrição e Resultados Simulados do `tb_hexa7seg`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `hexa = 4'h0 ... 4'hF` aplicados sequencialmente | `display` deve corresponder ao mapa esperado para cada dígito hexadecimal | Sim, se todas as 16 comparações passarem | Registrar o valor de entrada e o padrão de 7 segmentos divergente |

## 4.3.2 Cenário de Teste 2 — `tb_sample_width_adapter_24_to_18`

Este cenário verifica a política de truncamento do adaptador de largura de palavra entre 24 bits e 18 bits. O objetivo é confirmar que o DUT preserva a regra `sample_18 = sample_24[23:6]` para valores positivos, negativos e extremos relevantes.

Também é validada a propagação do sinal de validade, assegurando que o bloco não gere `valid` espúrio nem perca a associação entre dado e controle.

**Tabela 2 – Descrição e Resultados Simulados do `tb_sample_width_adapter_24_to_18`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `sample_24_i = 0`, `valid_24_i = 0` | `sample_18_o = 0`, `valid_18_o = 0` | Sim, se o caso base passar | Informar se houve lixo residual ou `valid` indevido |
| Amostras positivas (`64`, `128`, `8388480`) com `valid_24_i = 1` | Conversão truncada correta para `1`, `2`, `131070` | Sim, se todas as comparações passarem | Registrar saturação/truncamento incorreto |
| Amostras negativas (`-64`, `-128`, `-8388480`) com `valid_24_i = 1` | Conversão truncada correta preservando sinal | Sim, se o sinal e magnitude forem preservados | Registrar erro de sinal ou magnitude |

## 4.3.3 Cenário de Teste 3 — `tb_i2s_master_clock_gen`

Este cenário verifica o gerador de clock mestre I2S. O objetivo é assegurar que `sck_o` respeite o divisor configurado e que `ws_o` alterne com a periodicidade de meia moldura esperada.

O teste observa contadores internos de toggles e rejeita alterações de `SCK` fora do número esperado de bordas de `clk`, o que é essencial para o restante do pipeline I2S.

**Tabela 3 – Descrição e Resultados Simulados do `tb_i2s_master_clock_gen`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `CLOCK_DIV = 4`, reset inicial e execução por múltiplos ciclos | `sck_o` deve alternar exatamente a cada `CLOCK_DIV` bordas de `clk` | Sim, se nenhuma assertiva de divisor falhar | Registrar jitter lógico ou número incorreto de ciclos |
| Execução por duas meias molduras completas | `ws_o` deve alternar ao menos duas vezes | Sim, se `ws_transition_count >= 2` | Registrar falta de alternância ou janela incorreta |

## 4.3.4 Cenário de Teste 4 — `tb_i2s_rx_adapter_24`

Este cenário valida a reconstrução de amostras I2S de 24 bits a partir de uma sequência serial MSB-first com atraso de um bit e preenchimento lateral. O objetivo é provar que o receptor captura o canal correto e emite uma única indicação válida por amostra completa.

As amostras incluem valores positivos, negativos, extremos intermediários e zero, o que fornece uma boa cobertura funcional para o receptor.

**Tabela 4 – Descrição e Resultados Simulados do `tb_i2s_rx_adapter_24`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Sequência ROM com 8 amostras serializadas em I2S | Cada amostra recebida deve ser idêntica à amostra enviada | Sim, se todas as 8 comparações passarem | Registrar índice, valor esperado e valor reconstruído |
| Transição `WS` de canal direito para esquerdo + atraso I2S de 1 bit | Início da captura apenas no slot correto | Sim, se não houver deslocamento de bits | Registrar offset de frame ou amostra corrompida |
| Fila de amostras monitoradas entre transmissões | Fila deve esvaziar antes de cada novo caso | Sim, se não houver amostras remanescentes | Registrar duplicação/perda de eventos |

## 4.3.5 Cenário de Teste 5 — `tb_fft_control`

Este cenário verifica a lógica de disparo de `run` da FFT em função do estado do buffer de entrada e da atividade de ingestão. O objetivo é garantir que `run` só suba nas condições corretas e seja limpo quando o sistema retornar ao estado ocioso.

Além da subida nominal, o testbench cobre a persistência temporária em condição de `FFT_FULL`, ajudando a validar o comportamento temporal do controle.

**Tabela 5 – Descrição e Resultados Simulados do `tb_fft_control`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `sact_istream_i = 1`, `status = IDLE` | `run = 0` | Sim, se `run` não subir sem buffer cheio | Registrar subida espúria |
| `sact_istream_i = 1`, `status = FFT_FULL` | `run = 1` | Sim, se `run` subir apenas na condição correta | Registrar ausência de disparo |
| Retorno para `status = IDLE` | `run` deve voltar para `0` | Sim, se o controle limpar corretamente | Registrar travamento em estado ativo |
| Persistência por um ciclo em `FFT_FULL` | `run` deve permanecer ativo pelo intervalo previsto | Sim, se o pulso tiver a duração esperada | Registrar pulso curto ou excessivo |

## 4.3.6 Cenário de Teste 6 — `tb_fft_dma_reader`

Este cenário valida o leitor DMA da FFT em um caso curto de quatro bins. O objetivo é confirmar endereçamento, latência de leitura, associação de dados real/imaginário e sinalização de último bin.

O ambiente usa memórias locais como modelo de resposta do barramento DMA, o que permite rastrear com precisão a correspondência entre endereço pedido e bin emitido.

**Tabela 6 – Descrição e Resultados Simulados do `tb_fft_dma_reader`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `done_i` pulsado após reset | Leitura sequencial dos bins deve ser iniciada | Sim, se a máquina DMA sair de idle | Registrar ausência de varredura |
| Memórias `real_mem` e `imag_mem` com quatro valores conhecidos | `fft_bin_real_o` / `fft_bin_imag_o` devem reproduzir a memória na ordem correta | Sim, se cada bin casar com o índice correspondente | Registrar bin fora de ordem ou valor incorreto |
| Último índice (`FFT_LENGTH-1`) | `fft_bin_last_o = 1` somente no último bin | Sim, se o marcador ocorrer uma única vez | Registrar `last` adiantado, atrasado ou ausente |
| Final da sequência | `dmaact_o` deve retornar a idle | Sim, se o leitor encerrar corretamente | Registrar travamento ativo após a leitura |

## 4.3.7 Cenário de Teste 7 — `tb_i2s_stimulus_manager_rom`

Este cenário valida o gerador de estímulos I2S orientado por ROM e sua interação com um receptor I2S de checagem. O objetivo é comprovar que o bloco reproduz as amostras do exemplo selecionado, respeita a serialização I2S e isola o canal inativo com alta impedância.

O testbench cobre explicitamente o modo sem loop para o exemplo selecionado e utiliza um receiver auxiliar para validar a sequência observada na saída serial do DUT.

**Tabela 7 – Descrição e Resultados Simulados do `tb_i2s_stimulus_manager_rom`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| `start_i` com `example_sel_i` apontando para um exemplo da ROM | Reprodução das amostras correspondentes ao exemplo selecionado | Sim, se `rx_sample` coincidir com a ROM esperada | Registrar endereço, valor esperado e valor recebido |
| `chipen_i`, `lr_i`, `sck_i` e `ws_i` válidos | Serialização I2S coerente e observável no receptor auxiliar | Sim, se o receiver capturar a sequência correta | Registrar quebra de framing/temporização |
| Janela de canal inativo | `sd_o` deve apresentar `Z` no slot não selecionado | Sim, se `saw_z_on_inactive` for observado | Registrar disputa de barramento ou nível indevido |

## 4.3.8 Cenário de Teste 8 — `tb_aces_audio_to_fft_pipeline`

Este cenário integra recepção I2S, reconstrução de amostra, adaptação de largura e geração da interface de ingestão da FFT. O objetivo é validar a continuidade funcional entre os blocos de frontend e o stream real/imag do pipeline.

O caso usa três amostras de entrada com sinais distintos para verificar tanto a propagação dos dados quanto o pulso de ingestão de um ciclo.

**Tabela 8 – Descrição e Resultados Simulados do `tb_aces_audio_to_fft_pipeline`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Três amostras de 24 bits serializadas via I2S | `sample_mic_o` e `fft_sample_o` devem refletir `sample[23:6]` | Sim, se todas as capturas coincidirem | Registrar índice e amostra divergente |
| Evento válido de ingestão | `sact_istream_o` deve marcar o recebimento da amostra | Sim, se houver uma captura por amostra | Registrar pulso ausente ou repetido |
| Interface FFT real/imag | `sdw_istream_real_o` deve carregar a amostra truncada e `imag = 0` | Sim, se o stream real/imag for coerente | Registrar imag não nulo ou real incorreto |

## 4.3.9 Cenário de Teste 9 — `tb_aces`

Este cenário valida a integração do bloco `aces` com o gerador de estímulos e o mock da FFT. O objetivo é assegurar que as amostras saiam corretamente do frontend, entrem na FFT e retornem pela interface de transmissão de bins com ordenação consistente.

Por ser um teste de integração, ele cobre simultaneamente estímulo I2S, captura de amostra, controle de FFT e leitura dos bins resultantes.

**Tabela 9 – Descrição e Resultados Simulados do `tb_aces`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Início do stimulus manager no exemplo `0` | `sample_mic_o` deve reproduzir as quatro primeiras amostras truncadas esperadas | Sim, se `mic_count == FFT_LENGTH` e cada amostra casar | Registrar amostra faltante, extra ou incorreta |
| Execução do caminho FFT mock | `fft_tx_index_o` deve avançar monotonicamente | Sim, se o índice acompanhar `fft_bin_count` | Registrar reordenação de bins |
| Saída de bins real/imaginária | `fft_tx_real_o = idx+1`, `fft_tx_imag_o = -idx`, `fft_tx_last_o` no último bin | Sim, se todos os bins seguirem o contrato | Registrar valor real/imag ou `last` incorreto |

## 4.3.10 Cenário de Teste 10 — `tb_top_level_test`

Este cenário valida o top-level orientado à placa com ênfase na nova estratégia de debug capturado. O objetivo é confirmar que o stimulus manager realmente injeta amostras no sistema e que os snapshots de LEDs, HEX e GPIO refletem a página de debug selecionada.

O teste também verifica a infraestrutura de captura via GPIO, importante para congelar sinais internos rápidos e transferi-los para dispositivos lentos de observação na FPGA.

**Tabela 10 – Descrição e Resultados Simulados do `tb_top_level_test`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Reset, limpeza dos registradores de captura e pulso de `SW0` | O stimulus manager deve sair de pronto para ocupado/concluído | Sim, se `stim_busy_o` ou `stim_done_o` for observado | Registrar falha de partida do top-level |
| Seleção Stage 0 / Page 0 + pulso de captura | LEDs e GPIOs capturados devem refletir `{window_done, done, busy, ready}` | Sim, se snapshots casarem com os sinais internos | Registrar divergência entre mux e snapshot |
| Seleção Stage 1 / Page 0 + pulso de captura | GPIOs capturados devem refletir `{lr_sel, chipen, ws, sck}` | Sim, se os sinais I2S forem capturados corretamente | Registrar erro de roteamento nos probes |
| Displays HEX após captura | `HEX0..HEX5` não devem permanecer indefinidos | Sim, se a codificação 7-seg for válida | Registrar nibble inválido ou display indefinido |

## 4.3.11 Cenário de Teste 11 — `tb_fft_tx_bridge_fifo`

Este cenário valida a FIFO dedicada à ponte entre a leitura DMA da FFT e o backend de transmissão I2S. O objetivo é garantir que os campos `real`, `imag`, `last` e `bfpexp` permaneçam alinhados em cada entrada e que a ordem dos bins seja preservada mesmo em operações simultâneas de push e pop.

O testbench cobre reset, enchimento, leitura, overflow e o caso crítico de `push+pop` no mesmo ciclo, que é justamente o comportamento esperado quando a FFT ainda produz bins enquanto o serializador já começou a drenar a fila.

**Tabela 11 – Descrição e Resultados Simulados do `tb_fft_tx_bridge_fifo`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Reset inicial sem `push_i`/`pop_i` | `empty_o = 1`, `valid_o = 0`, `level_o = 0`, `overflow_o = 0` | Sim, se o estado inicial for coerente | Registrar flag inicial incorreta ou lixo residual |
| Dois pushes com bins conhecidos | Cabeça da FIFO deve refletir o primeiro bin e `level_o = 2` | Sim, se a ordenação e o nível forem preservados | Registrar bin fora de ordem ou ocupação incorreta |
| Enchimento até `FIFO_DEPTH` | `full_o = 1` e `level_o = FIFO_DEPTH` | Sim, se a FIFO sinalizar cheia no instante correto | Registrar saturação prematura ou ausência de `full` |
| Push extra com FIFO cheia | `overflow_o` deve pulsar e o conteúdo anterior deve permanecer íntegro | Sim, se o write for rejeitado sem corromper a fila | Registrar corrupção de dados ou overflow ausente |
| `push_i` e `pop_i` simultâneos | A ocupação deve se manter e o novo bin deve entrar no final da fila | Sim, se a ordem final for preservada | Registrar perda, duplicação ou desalinhamento de bin |

## 4.3.12 Cenário de Teste 12 — `tb_i2s_fft_tx_adapter`

Este cenário valida o adaptador que converte bins da FFT em palavras I2S etiquetadas. O objetivo é verificar não apenas os valores transmitidos, mas também a temporização do serializador: período de `SCK`, avanço de `WS` um bit antes do próximo `MSB` e ordenação dos frames entre janelas FFT.

O bench usa duas janelas FFT com expoentes distintos e decodifica o barramento serial em palavras novamente, permitindo checar a sequência completa de frames `BFPEXP` e `FFT` com asserts estruturais e temporais.

**Tabela 12 – Descrição e Resultados Simulados do `tb_i2s_fft_tx_adapter`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Cinco bins organizados em duas janelas FFT | Inserção de `BFPEXP` antes de cada janela e bins serializados em ordem | Sim, se a sequência decodificada casar com a esperada | Registrar frame ausente, fora de ordem ou com tag incorreta |
| `CLOCK_DIV = 2` durante a transmissão | `i2s_sck_o` deve alternar com período lógico constante | Sim, se nenhuma assertiva temporal falhar | Registrar jitter lógico ou divisor incorreto |
| Slots I2S completos de 32 bits | `i2s_ws_o` deve antecipar exatamente o último bit do slot atual, sinalizando o próximo canal sem deslocar payload | Sim, se o framing Philips I2S permanecer consistente | Registrar antecipação ausente, precoce ou desalinhamento do payload |
| Handshake com registrador pendente de 1 entrada | `fft_ready_o`, `fifo_full_o`, `fifo_empty_o` e `fifo_level_o` devem refletir o estado interno | Sim, se os sinais permanecerem coerentes | Registrar backpressure incorreto ou flag inconsistente |

## 4.3.13 Cenário de Teste 13 — `tb_fft_tx_i2s_link`

Este cenário integra a FIFO de ponte com o adaptador I2S, modelando o caso real em que a FFT produz bins em burst e o link serial os consome mais lentamente. O objetivo é comprovar o desacoplamento temporal entre produtor e consumidor sem perda de ordenação.

O bench injeta duas janelas FFT consecutivas, mede a ocupação máxima da FIFO, verifica ausência de overflow e decodifica a saída serial para confirmar que a sequência transmitida continua idêntica à do cenário unitário do adaptador.

**Tabela 13 – Descrição e Resultados Simulados do `tb_fft_tx_i2s_link`**

| Entradas | Saídas Esperadas | Resultado Simulado OK? | Análise de Não Conformidades |
| --- | --- | --- | --- |
| Burst de bins aplicados na FIFO em ciclos consecutivos | `fifo_level_o` deve crescer acima de 1 antes do escoamento completo | Sim, se a FIFO desacoplar produtor e consumidor | Registrar ocupação insuficiente ou ausência de desacoplamento |
| Handshake `valid_o/fft_ready_o` entre FIFO e adapter | `bridge_pop_i` deve ocorrer somente quando ambos estiverem aptos | Sim, se o pop ocorrer apenas em condição válida | Registrar leitura espúria ou perda de sincronismo entre módulos |
| Saída I2S decodificada após duas janelas FFT | Mesma sequência de tags e payloads esperada no backend serial | Sim, se todos os frames coincidirem | Registrar divergência entre caminho isolado e caminho integrado |
| Execução completa sem saturar a cadeia | `fifo_overflow_o = 0` e `adapter_overflow_o = 0` | Sim, se não houver violação de protocolo nem perda de dados | Registrar o estágio e o instante da saturação observada |
