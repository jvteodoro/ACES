`overrun` no `arecord`/ALSA quase sempre significa:

> **o hardware/driver recebeu dados mais rápido do que o software conseguiu consumir**, e o buffer de captura estourou.

No teu caso FPGA → I2S → Raspberry Pi, isso pode vir de algumas causas bem típicas.

## O que é o overrun na prática

Na captura de áudio existe um buffer circular no lado do driver/ALSA.

A sequência é:

1. a interface I2S vai colocando amostras no buffer
2. o `arecord` vai tirando essas amostras
3. teu Python lê do `stdout` do `arecord`

Se, em algum momento, o produtor enche o buffer antes do consumidor drenar, acontece **overrun**.

---

## As causas mais prováveis no teu projeto

### 1. O Python está consumindo devagar demais

No logger, tu fazes:

* leitura do pipe
* conversão com `numpy`
* loop Python linha por linha
* `writer.writerow(...)` para cada frame
* `flush()` a cada chunk

Esse ponto é bem suspeito.

Porque escrever CSV linha a linha já é relativamente caro, e o `flush()` em todo chunk piora ainda mais. Se o stream entra continuamente, o `arecord` pode não conseguir escoar rápido o suficiente para o Python.

### 2. `chunk_frames` está pequeno demais

Se o chunk é pequeno, o sistema faz muitas iterações:

* mais chamadas de leitura
* mais loops Python
* mais flushes
* mais syscalls

Isso aumenta overhead e favorece overrun.

### 3. Mismatch entre taxa real do clock e taxa configurada no `arecord`

Se a FPGA está gerando clocks que não batem exatamente com o que o ALSA acredita, o comportamento pode ficar estranho.

Exemplo:

* o `arecord` é aberto com `-r 48000`
* mas a FPGA na prática entrega outra taxa efetiva
* o driver tenta operar com um ritmo diferente do fluxo físico

Isso pode gerar instabilidade, erro de sincronização e XRUN/overrun.

### 4. O overlay/driver não está confortável com clock externo

Esse é um ponto importante no Raspberry Pi.

Mesmo que o card apareça no ALSA, o caminho:

* overlay
* driver
* modo slave
* clocks externos vindos da FPGA

pode não estar realmente estável. Aí aparecem sintomas como:

* captura errática
* XRUN
* overrun
* zeros
* dados corrompidos

### 5. O processo `arecord` está recebendo dados, mas o pipeline downstream trava por disco/I/O

Se o cartão SD está lento, ou o sistema está carregado, o CSV pode atrasar o consumidor.

### 6. Formato/canais não batem com o esperado

Se o `arecord` está configurado de uma forma e o fluxo I2S real não bate exatamente, às vezes o driver entra em comportamento ruim. Não é a causa mais clássica de overrun, mas pode contribuir.

---

## No teu logger, os suspeitos mais fortes

Eu colocaria nesta ordem:

### Mais provável

1. **`flush()` a cada chunk**
2. **escrita CSV linha por linha em Python**
3. **chunk pequeno demais**

### Depois

4. **problema de clock/rate real**
5. **overlay/driver inadequado para FPGA-master**
6. **carga geral do Raspberry Pi**

---

## Por que o logger é especialmente vulnerável

Teu código faz isto:

```python
for row in stereo:
    writer.writerow([timestamp_ns_fn(), seq, int(row[0]), int(row[1])])
...
f_csv.flush()
```

Isso é funcional, mas para fluxo contínuo é pesado porque:

* cada frame vira uma chamada Python
* cada linha gera formatação CSV
* cada chunk força gravação em disco

Então o logger é muito mais lento do que um receptor que só:

* lê blocos
* guarda em buffer binário
* ou processa por lotes maiores

---

## Como diagnosticar melhor

### Teste 1: aumentar `chunk_frames`

Experimenta algo como:

* `512`
* `1024`
* `2048`

Se o overrun diminuir, era muito provavelmente overhead por chunk pequeno.

### Teste 2: remover `flush()` a cada chunk

Trocar por:

* flush periódico
* ou flush só no final
* ou a cada N chunks

Se melhorar, achaste uma causa importante.

### Teste 3: testar sem CSV

Faz um teste curto lendo e descartando os dados, sem escrever arquivo.

Se sem escrita não dá overrun, então o gargalo está no logger/I/O.

### Teste 4: rodar `arecord` puro

Por exemplo, gravar para `/dev/null` ou arquivo bruto.

Se o `arecord` sozinho já dá overrun, o problema está mais embaixo:

* driver
* overlay
* clocks
* hardware

Se só dá overrun quando entra o Python, o gargalo é teu consumidor.

### Teste 5: conferir clocks reais

Medir:

* BCLK
* LRCLK

e verificar se o LRCLK realmente corresponde ao sample rate esperado.

---

## Sinais matemáticos do problema

Teu fluxo bruto é, aproximadamente:

* 2 canais
* 32 bits por canal
* 48 kframes/s

Taxa de dados:

[
48000 \times 2 \times 32 = 3{,}072{,}000 \text{ bits/s}
]

ou

[
384000 \text{ bytes/s}
]

Isso não é absurdo para a Pi. Então, em tese, o sistema deveria aguentar.

Por isso, quando aparece overrun, geralmente o problema não é “largura de banda impossível”, e sim:

* overhead de software
* driver/configuração
* sincronização ruim

---

## O que eu faria primeiro

Eu faria exatamente esta sequência:

1. aumentar `--chunk-frames`
2. remover ou reduzir `f_csv.flush()`
3. testar um modo sem escrita CSV
4. testar `arecord` isolado
5. conferir se a taxa de clock da FPGA bate com o `-r`
6. revisar se o overlay realmente está adequado para Pi slave com clock externo

---

## Suspeita bem concreta no teu código

Se eu tivesse que apostar no erro mais imediato, eu apostaria em:

> **o logger está pesado demais para rodar em tempo real por causa da escrita CSV linha a linha com flush frequente**.

Porque isso é exatamente o tipo de coisa que provoca overrun mesmo quando a taxa nominal não é alta.

---

## Como mitigar no código

As melhorias mais diretas seriam:

* usar chunks maiores
* acumular linhas e escrever em lote
* não dar `flush()` em todo chunk
* opcionalmente gravar binário em vez de CSV
* separar captura e gravação em threads/processos
* usar uma fila entre leitura e escrita

---

## Resumo

`overrun` significa que o caminho de captura não conseguiu drenar os dados a tempo. No teu caso, as causas mais prováveis são:

* logger pesado demais
* `flush()` excessivo
* chunks pequenos
* mismatch de clock/rate
* overlay/driver não ideal para FPGA-master com clock externo

O teste mais útil agora é comparar:

* `arecord` sozinho
* logger sem escrita
* logger com chunks maiores e sem flush por chunk

Se quiser, eu posso te propor uma versão modificada desse logger para reduzir muito a chance de overrun.



## Contexto técnico: logger I2S/ALSA, `arecord` e erro de overrun

Estamos usando um logger Python que lê o stream de captura via `arecord`, interpreta cada frame estéreo `S32_LE` como um par `(real, imag)` de 32 bits e grava isso em CSV. No Raspberry Pi, o overlay é configurado via `config.txt` com `dtoverlay=...`; isso é configuração de **Device Tree**, não do ALSA diretamente. O ALSA só enxerga a sound card depois que o boot aplica o overlay e o driver registra o dispositivo. A documentação oficial da Raspberry Pi descreve `dtoverlay` e `dtparam` exatamente nesse papel. ([Raspberry Pi][1])

### Descobertas principais sobre o erro observado

O comportamento observado foi: **algumas linhas do CSV saem com valores válidos e, em outros momentos, aparece erro de overrun**.

A interpretação mais importante é:

* isso **não parece** um caso de enlace totalmente morto;
* o Pi está conseguindo capturar dados válidos por algum tempo;
* o problema é mais compatível com **perda intermitente de ritmo** no caminho de captura do que com ausência total de sinal.

Em ALSA/`arecord`, **overrun** significa que os dados chegaram ao buffer de captura mais rápido do que o software conseguiu drenar, e parte dos dados precisou ser descartada. Isso é consistente tanto com explicações da comunidade ALSA quanto com discussões práticas sobre `arecord`. ([Blokas Community][2])

### Hipótese mais forte no nosso caso

A hipótese principal é que o **logger está pesado demais para tempo real** no formato atual.

O logger hoje faz, por chunk:

1. leitura do `stdout` do `arecord`;
2. conversão com `numpy.frombuffer`;
3. loop Python linha por linha;
4. `writer.writerow(...)` para cada frame;
5. `flush()` a cada chunk.

Esse padrão é funcional, mas adiciona bastante overhead de CPU e I/O. Se em algum instante o consumidor atrasar alguns milissegundos, o buffer de captura pode estourar e o `arecord` reporta overrun. Isso é coerente com a descrição geral de overrun em gravação ALSA. ([Blokas Community][2])

### Suspeitos ordenados por probabilidade

#### 1. Overhead do próprio logger

Mais provável:

* escrita CSV linha por linha;
* `flush()` em todo chunk;
* chunks pequenos demais, gerando muitas iterações e syscalls.

#### 2. Configuração de chunk inadequada

Se `chunk_frames` estiver baixo, o sistema faz muitas leituras pequenas, muitas conversões e muitas escritas, o que aumenta o overhead total.

#### 3. Mismatch entre taxa real da FPGA e taxa aberta no ALSA

Se a FPGA estiver gerando clocks cuja taxa efetiva não bate com o `-r` configurado no `arecord`, pode haver instabilidade operacional ou comportamento ruim do caminho de captura.

#### 4. Overlay/driver não ideais para FPGA como I2S master

O fato de a sound card aparecer no ALSA não prova que o caminho esteja robusto para **BCLK/LRCLK externos**. Há casos e discussões no ecossistema Raspberry Pi mostrando que o papel master/slave e o overlay escolhido influenciam bastante o comportamento da interface I2S. ([Fóruns Raspberry Pi][3])

#### 5. Carga geral do sistema / escrita em disco

Escrever CSV continuamente no cartão SD pode introduzir atrasos periódicos suficientes para provocar overrun.

### O que o sintoma “algumas linhas válidas” sugere

Esse sintoma sugere que:

* o parsing bruto não está totalmente errado;
* há pelo menos momentos em que left/right chegam de forma plausível;
* o problema é provavelmente de **sustentação contínua** da captura, não de impossibilidade absoluta de captura.

Ou seja: o enlace básico parece vivo, mas ainda **não está robusto em regime contínuo**.

### Conclusão operacional atual

No estado atual, devemos assumir que o problema mais provável está no lado de software do logger e/ou no custo de I/O, antes de concluir que o hardware ou o framing I2S estão totalmente errados.

### Testes que distinguem gargalo de software versus problema de transporte

Os testes prioritários são:

1. **Aumentar `--chunk-frames`** para valores como `1024` ou `2048`.
   Se o overrun reduzir, isso aponta para overhead excessivo por chunk pequeno.

2. **Remover temporariamente o `flush()` por chunk**.
   Se melhorar, o gargalo era em parte de escrita/I/O.

3. **Criar um modo de teste que leia e descarte os dados sem escrever CSV**.
   Se sem escrita não houver overrun, a causa principal está no logger, não no transporte I2S.

4. **Testar `arecord` isoladamente**, sem o logger Python.
   Se `arecord` sozinho já der overrun, o problema está mais abaixo: driver, overlay, clocks ou configuração ALSA.

5. **Medir BCLK e LRCLK no osciloscópio/analisador lógico** e verificar se a taxa real bate com o que está sendo pedido ao `arecord`.

### Direção de melhoria sugerida para o logger

O logger deve ser refatorado para reduzir risco de overrun. As melhorias mais importantes são:

* aumentar o tamanho dos chunks;
* parar de dar `flush()` a cada chunk;
* escrever CSV em lote, não linha por linha;
* opcionalmente oferecer modo binário/raw para debug de alto desempenho;
* separar captura e persistência com fila/thread, se necessário.

### Observação adicional sobre overlay

O script de setup atual usa `dtoverlay=...` no `config.txt`, o que está conceitualmente correto para Raspberry Pi, porque overlays são Device Tree overlays aplicados no boot. Porém, isso não garante por si só que o overlay seja o melhor para **FPGA como I2S master com clocks externos**. Para esse cenário, o projeto deve caminhar para um overlay mais explícito e orientado a Pi em slave, em vez de depender apenas de um overlay genérico/fallback. ([Raspberry Pi][1])

---

## Resumo curto para orientar implementação

* `overrun` significa que o caminho de captura não está drenando os dados rápido o suficiente. ([Blokas Community][2])
* Como algumas linhas válidas aparecem antes do erro, o enlace não parece totalmente morto.
* A hipótese mais forte é **overhead do logger**: CSV linha a linha + `flush()` por chunk + chunk pequeno.
* Também é possível haver contribuição de overlay/driver inadequado para clock externo, ou mismatch de taxa real.
* Antes de culpar hardware, o logger deve ser tornado mais leve e testado com chunks maiores, sem flush frequente e com modo de descarte sem escrita.
* O setup via `dtoverlay` está na camada de Device Tree/boot, não diretamente na camada ALSA. ([Raspberry Pi][1])

---

[1]: https://www.raspberrypi.com/documentation/computers/config_txt.html?utm_source=chatgpt.com "config.txt - Raspberry Pi Documentation"
[2]: https://community.blokas.io/t/overruns-with-arecord-at-192-khz-2-channel/575?utm_source=chatgpt.com "Overruns with arecord at 192 khz 2 channel - Support"
[3]: https://forums.raspberrypi.com/viewtopic.php?t=396534&utm_source=chatgpt.com "CM5 I2S1 Slave Mode - External Clock Not Detected (ISR ..."
