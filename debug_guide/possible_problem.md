Sim — agora apareceu um indício bem mais forte de causa raiz.

## Diagnóstico principal

O problema **mais provável está no RTL do transmissor I2S**, não no parser Python.

Pelo que vi no `i2s_fft_tx_adapter.sv`, o módulo diz que cada bin FFT ocupa um frame I2S com:

* `left = real`
* `right = imag`

e usa tags `0=IDLE`, `1=BFPEXP`, `2=FFT`.

Mas a máquina de estados atual **carrega o próximo par ativo no fim do slot esquerdo**, não no fim do slot direito. Em termos práticos, isso tende a fazer o “par semântico” aparecer no fio como:

* **right primeiro**
* **left depois**

em vez de left→right.

### Por que isso importa

O receiver/ALSA agrupa o stream como pares estéreo `[left, right]`. No Python, cada par bruto é interpretado assim, e o parser tagged também assume que os dois words de um par deveriam compartilhar a mesma tag antes de classificar como `idle`, `bfpexp` ou `fft`.

Se o transmissor estiver atualizando o payload/tag na fronteira errada, o host pode acabar vendo pares misturados, por exemplo:

* left de um item
* right do item seguinte

Isso gera exatamente os sintomas que apareceram nos logs:

* muitos `tag_mismatch`
* runs de FFT muito curtas
* transições demais entre `idle`, `bfpexp`, `fft`, `other`

## O que nos logs confirma isso

O conjunto de debug foi rodado em três cenários sobre a **mesma captura bruta**, justamente para comparação justa entre hipóteses: `strict_tags_shift30`, `relaxed_tags_shift30` e `relaxed_tags_shift29`. O próprio script da matriz foi feito para isso.

Além disso, nessa sessão:

* `bfpexp_flag_line=none`
* `tag_shift=30`
* `payload_bits=18`
* `tag_idle=0`, `tag_bfpexp=1`, `tag_fft=2`
* `chunk_pairs=1024`
* device ALSA detectado como `Google voiceHAT SoundCard HiFi` em `card 2, device 0`. 

Eu parseei os resumos dos três JSONL e todos deram ruim de forma muito parecida:

* `strict_tags_shift30`:
  `idle=72528`, `bfpexp=4567`, `fft=5456`, `tag_mismatch=60784`, `other=24601`, `max_fft_run=3`
* `relaxed_tags_shift30`:
  `idle=73757`, `bfpexp=4410`, `fft=5242`, `tag_mismatch=59828`, `other=25211`, `max_fft_run=4`
* `relaxed_tags_shift29`:
  `idle=73463`, `bfpexp=4514`, `fft=5322`, `tag_mismatch=61359`, `other=25326`, `max_fft_run=4`

### Interpretação

Isso é importante por dois motivos:

1. **mudar `tag_shift` de 30 para 29 quase não melhora nada**
   Então o problema **não parece ser só “tag shift errado”**.

2. O `max_fft_run` deveria ser grande se o stream estivesse bem enquadrado
   Para uma janela de 512 bins, você esperaria rajadas FFT muito longas.
   Ver `max_fft_run=3` ou `4` é completamente incompatível com um stream corretamente agrupado.

## Outro sinal forte: muitos `reserved_nonzero_words`

O debug do analyzer conta explicitamente:

* `tag_mismatch`
* `reserved_nonzero_words`
* `fft_run_lengths`
* transições entre classes.

Nos resumos, `reserved_nonzero_words` ficou gigantesco:

* ~272k
* ~271k
* ~265k

Se o packing fosse realmente:

* bits `[31:30]` = tag
* bits intermediários reservados = zero
* payload signed nos bits baixos,

então esse número deveria ser muito menor. Isso reforça que o host está vendo palavras desalinhadas ou misturadas.

## Onde está o bug provável no RTL

No `i2s_fft_tx_adapter.sv`, a fronteira de atualização do payload ativo está ligada a:

```verilog
if (channel_r == 1'b0)
    frame_boundary = 1'b1;
```

dentro do caso em que `slot_bit_r == I2S_SLOT_W-1`.

Ou seja, a troca do `active_tag_r`, `active_left_r` e `active_right_r` acontece quando o canal atual era o **esquerdo**. Pela lógica do seu transmissor, isso joga o novo conteúdo para começar no slot seguinte, que é o **direito**.

Esse detalhe é suficiente para quebrar o emparelhamento left/right no host.

## Em linguagem direta

Hoje o transmissor provavelmente está fazendo algo mais próximo de:

* termina `left`
* carrega próximo par
* transmite `right` do próximo item
* depois transmite `left` desse mesmo item

em vez de:

* termina `right`
* carrega próximo par
* transmite `left`
* depois `right`

Para um host ALSA que reconstrói frames estéreo convencionais, isso é péssimo.

## Por que isso bate com o Python

No Python, o receiver tagged faz:

* decodificar tag por word
* comparar tag left e tag right
* classificar o par
* só aceitar frame FFT quando enxerga uma sequência coerente de pares FFT.

Se os pares no fio já chegam “cortados na costura”, o parser não tem como consertar.

Então, neste momento, eu colocaria a prioridade assim:

### Causa raiz mais provável

**fronteira errada de atualização no serializer I2S**

### Consequência observável

* `tag_mismatch` enorme
* `other` alto
* `reserved_nonzero_words` enorme
* rajadas FFT minúsculas

## Questões secundárias, mas não principais

Tem mais duas coisas que continuam merecendo atenção:

### 1. O logger CSV continua pesado

Ele ainda pode causar `overrun`, mas isso não explica sozinho a estrutura dos logs tagged.

### 2. O parser `_pair_kind_and_payload()` trata tag diferente entre canais como `"other"`

No debug ele aparece corretamente como `tag_mismatch`, mas no receiver normal isso vira apenas `"other"`, o que mascara erro estrutural.

Isso não é a causa primária, mas vale endurecer depois.

## O que eu recomendo mudar no RTL

No transmissor:

* a carga do próximo `active_*` deve acontecer na fronteira que antecede o **slot esquerdo** do novo frame estéreo, não a que antecede o slot direito;
* em outras palavras, a atualização deve ser alinhada para que o host veja sempre:

  * left = `active_left`
  * right = `active_right`

### Teste objetivo após corrigir

Depois da correção, no mesmo debug matrix você deveria ver algo próximo de:

* `tag_mismatch ≈ 0`
* `reserved_nonzero_words ≈ 0`
* `other ≈ 0` ou muito baixo
* `max_fft_run` muito grande, idealmente perto de `512`
* `bfpexp` aparecendo como rajadas curtas previsíveis
* `fft` aparecendo em blocos longos

## Em resumo

Minha leitura agora é:

> o host não está “entendendo errado” um stream correto; o stream já está chegando semanticamente quebrado por causa do ponto em que o RTL troca o payload/tag ativo entre slots I2S.

Esse é o melhor candidato de longe para explicar o comportamento inteiro.