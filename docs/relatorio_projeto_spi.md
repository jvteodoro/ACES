# Relatório Técnico dos Módulos SPI

Este arquivo consolida texto-base para o relatório dos módulos SPI do projeto
ACES. O foco está no subsistema ativo de exportação da FFT para o Raspberry Pi,
centrado em `spi_fft_tx_adapter`, `fft_tx_bridge_fifo`, na integração com
`aces` e no top de diagnóstico `top_level_spi_fft_tx_diag`.

## Projeto do Fluxo de Dados

**Figura sugerida 1 – Panorama do fluxo de dados do subsistema SPI**

Inserir uma figura do panorama do fluxo de dados com a seguinte cadeia:

```text
fft_dma_reader
    -> spi_fft_tx_adapter
        -> fft_tx_bridge_fifo interno
        -> empacotamento em palavras tagged de 32 bits
        -> serializador SPI
    -> pinos GPIO da FPGA
    -> Raspberry Pi como mestre SPI
```

O fluxo de dados do subsistema SPI começa quando `fft_dma_reader` disponibiliza
os bins complexos da FFT por meio dos sinais `fft_valid_i`, `fft_real_i`,
`fft_imag_i`, `fft_last_i` e `bfpexp_i`. Esses dados entram em
`spi_fft_tx_adapter`, que é o bloco responsável por converter um fluxo interno
de bins em uma transação SPI orientada pelo host. Para isso, o adaptador recebe
cada bin, armazena-o em uma FIFO interna e só sinaliza `window_ready_o` quando
uma janela inteira foi acumulada, ou seja, quando um bin com `fft_last_i = 1`
foi efetivamente aceito.

Depois que existe uma janela completa disponível, o Raspberry Pi inicia a
transação SPI ao forçar `CS_N` para nível baixo e fornecer `SCLK`. O adaptador
então lê a cabeça da FIFO, estende os dados para a largura do protocolo,
empacota cada amostra em palavras tagged de 32 bits e serializa os bytes em
`spi_miso_o`. A transação envia primeiro os pares de BFPEXP e, em seguida, os
pares `{real, imag}` de cada bin da FFT, preservando o contrato lógico já
esperado pelo software do host, apesar da mudança do meio físico de transmissão.

### Destaque do Adaptador SPI

**Figura sugerida 2 – Visão interna do `spi_fft_tx_adapter`**

Inserir uma figura do RTL Viewer destacando os seguintes blocos internos:

- sincronização de `spi_sclk_i` e `spi_cs_n_i`;
- FIFO de ponte `fft_tx_bridge_fifo`;
- lógica de contagem de janelas completas;
- bloco de empacotamento tagged;
- serializador byte a byte e bit a bit.

O `spi_fft_tx_adapter` pode ser entendido como a composição de três caminhos
principais. O primeiro é o caminho de buffering, implementado pela FIFO
show-ahead `fft_tx_bridge_fifo`, que desacopla a produção dos bins FFT da taxa
de leitura SPI. O segundo é o caminho de formatação, no qual os dados são
convertidos para palavras de 32 bits no formato `[tag | zeros reservados |
payload assinado]`. O terceiro é o caminho de serialização, que transforma os
pares lógicos de palavras em bytes e bits apresentados em `spi_miso_o` segundo
as premissas de SPI modo 0.

Esse particionamento é importante porque separa claramente o problema de
armazenamento temporário do problema de protocolo físico. A FIFO resolve a
diferença de ritmo entre produtor e consumidor; o empacotamento preserva a
compatibilidade com o software do host; e o serializador garante que os dados
sejam emitidos na ordem correta de bytes e bits quando o mestre SPI os requisita.

## Projeto da Unidade de Controle

**Figura sugerida 3 – Diagrama de transição de estados da unidade de controle do `spi_fft_tx_adapter`**

Inserir aqui a figura do State Machine Viewer. Para o relatório, é importante
observar que a unidade de controle do adaptador SPI não foi escrita como uma FSM
única em `typedef enum`, mas como um controle distribuído em registradores como
`spi_transaction_active_r`, `active_pair_kind_r`, `bfpexp_hold_remaining_r`,
`wait_next_fft_pair_r`, `wait_fifo_refresh_r`, `pair_byte_idx_r`,
`current_bit_idx_r` e `byte_complete_pending_r`. Portanto, a tabela abaixo
descreve os estados funcionais do sistema, isto é, os estados equivalentes do
ponto de vista arquitetural, mesmo que a implementação RTL esteja distribuída.

**Tabela 5 – Descrição da Unidade de Controle do Sistema**

| Nome do Estado | Descrição do Estado | Próximo Estado | Condições e Justificativas para a Transição entre Estados |
| --- | --- | --- | --- |
| `RESET` | Inicializa contadores, limpa a indicação de transação ativa, zera o serializer e força `spi_miso_o` para zero. | `AGUARDA_TRANSACAO` | Após `rst` voltar a zero, o sistema entra em repouso aguardando dados completos e eventual requisição do host. Essa transição garante partida determinística do protocolo. |
| `AGUARDA_TRANSACAO` | Estado de repouso. Não há transação SPI ativa. Se existir ao menos uma janela completa, `window_ready_o` pode permanecer em alto. | `CARREGA_BFPEXP` ou `CARREGA_IDLE` | Quando `spi_cs_fall_w` ocorre, o host iniciou uma transação. Se `complete_windows_r != 0` e `fifo_valid_w = 1`, o adaptador deve começar a transmitir uma janela válida. Caso contrário, responde com palavras `IDLE`, evitando envio de lixo quando o host consulta cedo demais. |
| `CARREGA_BFPEXP` | Carrega nos registradores internos o primeiro par BFPEXP da janela e prepara o serializer para o primeiro byte e o primeiro bit. | `TRANSMITE_BFPEXP` | A transição é imediata após a carga do par. A justificativa é iniciar a transação com o campo de expoente compartilhado, conforme o contrato do host. |
| `TRANSMITE_BFPEXP` | Serializa o par BFPEXP atualmente ativo, byte a byte e bit a bit, usando `pair_byte_idx_r`, `current_byte_r` e `current_bit_idx_r`. | `TRANSMITE_BFPEXP` ou `CARREGA_FFT` ou `AGUARDA_TRANSACAO` | Enquanto ainda há bytes e bits pendentes, o estado permanece nele mesmo. Quando o par termina e `bfpexp_hold_remaining_r > 1`, um novo par BFPEXP é recarregado, preservando o número de repetições esperado pelo host. Quando a última repetição termina, o controle segue para a carga do primeiro par FFT. Se `CS_N` subir antes disso, a transação é abortada e o sistema retorna ao repouso. |
| `CARREGA_FFT` | Lê a cabeça atual da FIFO, empacota `{real, imag}` com tag FFT e arma o serializer para transmitir o próximo par FFT. | `TRANSMITE_FFT` | A transição ocorre logo após a preparação do par. A justificativa é que, terminado o cabeçalho BFPEXP, a janela deve prosseguir com os bins complexos na ordem em que foram recebidos. |
| `TRANSMITE_FFT` | Serializa o par FFT atualmente ativo. O par representa um bin completo, com parte real na palavra esquerda e parte imaginária na palavra direita. | `ESPERA_REFRESH_FIFO` ou `FINALIZA_JANELA` ou `AGUARDA_TRANSACAO` | Quando ainda restam bytes ou bits do mesmo par, o estado permanece nele mesmo. Quando o par termina e `active_fft_last_r = 0`, o bin enviado não era o último da janela, então é necessário remover a cabeça atual da FIFO e aguardar a atualização da nova cabeça. Quando `active_fft_last_r = 1`, a janela foi completamente transmitida e o sistema passa ao fechamento da transação lógica. Se `CS_N` subir em qualquer momento, a transação é abortada e o sistema volta ao repouso. |
| `ESPERA_REFRESH_FIFO` | Estado funcional correspondente ao atraso de um ciclo após `fifo_pop_r`, para que a FIFO show-ahead reflita corretamente a nova cabeça. | `CARREGA_FFT` | A transição ocorre depois que `wait_fifo_refresh_r` é limpo. A justificativa é evitar retransmitir dados obsoletos logo após o pop, respeitando o comportamento temporal da FIFO. |
| `FINALIZA_JANELA` | Remove logicamente a janela do contador `complete_windows_r`, descarrega o último bin e carrega palavras `IDLE` no serializer. | `CARREGA_IDLE` ou `AGUARDA_TRANSACAO` | Ao terminar o último bin FFT, o adaptador precisa encerrar a janela atual sem vazar a janela seguinte na mesma transação. Por isso, ele entra em uma condição de `IDLE` até que o host libere `CS_N`. |
| `CARREGA_IDLE` | Prepara o par de palavras nulas com tag `IDLE`. Esse estado é usado tanto para consulta sem janela pronta quanto para preenchimento após o fim da janela. | `TRANSMITE_IDLE` | A transição é imediata após a carga do par. A justificativa é manter um comportamento seguro e previsível no barramento, sem misturar transações distintas. |
| `TRANSMITE_IDLE` | Serializa palavras `IDLE` enquanto a transação permanecer ativa, sem consumir novos bins da FIFO. | `AGUARDA_TRANSACAO` ou `TRANSMITE_IDLE` | Se `CS_N` permanecer em baixo, o adaptador continua respondendo com `IDLE`, o que é útil tanto em sondagens quanto após o final da janela. Quando `spi_cs_rise_w` ocorre, a transação é encerrada e o sistema retorna ao estado de repouso. |

### Observação sobre a microarquitetura de controle

Além dos estados funcionais acima, existe uma microsequência interna de
serialização. Em SPI modo 0, o mestre amostra em borda de subida, então o
adaptador usa a borda de descida para adiantar o próximo bit de `spi_miso_o`.
Por isso, a unidade de controle mantém um controle fino de byte completo por meio
de `byte_complete_pending_r`, permitindo distinguir a troca de bit, a troca de
byte e a troca de par lógico no instante correto do protocolo.

Outro detalhe importante é o tratamento assíncrono do encerramento de transação.
Sempre que `spi_cs_rise_w` é detectado, o controle limpa o estado local da
transação, incluindo registradores do serializer e indicadores de janela em
progresso. Essa decisão simplifica a robustez do protocolo, pois garante que uma
nova transação sempre recomece de uma fronteira válida, independentemente de o
host ter encerrado a leitura no meio de um par ou ao final de uma janela.

## Projeto do Sistema Digital Programável

**Figura sugerida 4 – Integração entre fluxo de dados e unidade de controle do subsistema SPI**

Inserir uma figura legível mostrando a interação entre:

- produtor de bins FFT;
- `spi_fft_tx_adapter`;
- FIFO interna;
- sinais de controle de transação;
- pinos de interface com o Raspberry Pi;
- sinais de depuração do top de diagnóstico.

No sistema digital programável, o fluxo de dados e a unidade de controle estão
fortemente acoplados, mas preservam papéis bem definidos. O fluxo de dados cuida
da movimentação e transformação das informações: recebe os bins da FFT, armazena
os pares complexos, empacota as palavras tagged e serializa o resultado em
`spi_miso_o`. A unidade de controle, por sua vez, decide quando a FIFO pode ser
consumida, quando um novo par lógico deve ser carregado, quando o cabeçalho
BFPEXP termina, quando a janela foi concluída e quando a saída deve permanecer
em `IDLE`. Em outras palavras, o fluxo de dados implementa o “como transmitir” e
a unidade de controle implementa o “quando transmitir”.

Essa integração fica especialmente clara em `top_level_spi_fft_tx_diag`, onde o
adaptador SPI é alimentado por um gerador determinístico de bins. Nesse cenário,
o produtor só avança quando `diag_fft_ready_o` indica que o adaptador pode
aceitar novos dados, e o host só inicia a drenagem da janela quando
`tx_spi_window_ready_o` sinaliza que ela está completa. O resultado é um sistema
sincronizado por handshake nas duas extremidades: internamente pelo par
`valid/ready` e externamente pelo protocolo `window_ready` + SPI.

### Sinais de depuração úteis

Os sinais abaixo são os mais relevantes para observação em simulação, RTL Viewer,
SignalTap, osciloscópio ou analisador lógico:

- `window_ready_o`
  Indica que ao menos uma janela completa está pronta para leitura.
- `spi_active_o`
  Indica que uma transação SPI está em andamento.
- `overflow_o`
  Sinaliza tentativa de escrita rejeitada na FIFO interna.
- `fifo_level_o`
  Mostra a ocupação atual da FIFO e ajuda a distinguir gargalo de produção ou de drenagem.
- `fifo_full_o` e `fifo_empty_o`
  Permitem observar rapidamente saturação ou esvaziamento da FIFO.
- `complete_windows_r`
  Indica quantas janelas completas permanecem pendentes de leitura.
- `active_pair_kind_r`
  Mostra se o adaptador está emitindo `IDLE`, `BFPEXP` ou `FFT`.
- `pair_byte_idx_r`
  Indica qual byte do par lógico está sendo serializado.
- `current_bit_idx_r`
  Indica qual bit do byte atual está sendo transmitido.
- `byte_complete_pending_r`
  Facilita depurar a troca entre bytes em SPI modo 0.
- `diag_fft_ready_o`
  No top de diagnóstico, mostra se o adaptador está aceitando novos bins sintéticos.
- `diag_accept_w`
  Pulso de aceitação de bin no top de diagnóstico.
- `diag_window_done_w`
  Marca o fechamento de uma janela sintética no top de diagnóstico.
- `diag_overflow_latched_r`
  Mantém histórico de overflow para debug em bancada.
- `diag_heartbeat_r`
  Fornece evidência visual de atividade contínua do gerador de estímulo.
- `gpio_1_d27`, `gpio_1_d29` e `tx_spi_miso_o`
  São os sinais físicos principais do barramento SPI.

### Sugestão de redação para a figura de integração

O subsistema SPI do ACES implementa uma integração coesa entre datapath e
controle, na qual cada fronteira de comunicação é acompanhada por sinais que
tornam o comportamento observável. No lado interno, o handshake `valid/ready`
coordena a entrada dos bins da FFT na FIFO do adaptador. No lado externo, o
handshake `window_ready` informa ao Raspberry Pi quando a leitura de uma janela
pode ser iniciada, e o protocolo SPI propriamente dito realiza a drenagem serial
do conteúdo armazenado.

A presença de um top de diagnóstico dedicado amplia significativamente a
capacidade de verificação do sistema digital programável. Em vez de depender do
funcionamento simultâneo de captura I2S, processamento FFT e exportação SPI, o
projetista pode validar isoladamente a interface de transmissão e seus sinais de
depuração. Isso reduz a complexidade da análise e acelera o processo de
integração em FPGA e em bancada.
