Claro — segue um **texto de diagnóstico técnico** pronto para usar como contexto para o Codex.

---

## Diagnóstico técnico da captura incorreta no caminho FPGA → I2S → Raspberry Pi

Após analisar o módulo Python `rpi3b_i2s_fft`, o transmissor Verilog e os logs gerados pelo script de debug, a hipótese principal deixou de ser “problema do parser Python” e passou a ser **erro estrutural no transmissor I2S da FPGA**, especificamente na forma como os words left/right são atualizados entre os slots do frame estéreo.  

### Resumo do problema observado

Os sintomas no Raspberry Pi foram:

* capturas intermitentemente plausíveis;
* erros de `overrun` em alguns testes;
* e, nos logs de debug tagged, grande quantidade de:

  * `tag_mismatch`,
  * `other`,
  * `reserved_nonzero_words`,
  * e rajadas FFT muito curtas.

Esses sintomas são incompatíveis com um stream tagged corretamente empacotado em que cada par estéreo represente semanticamente:

* left = valor esquerdo do item atual
* right = valor direito do item atual

No sistema Python, o receiver tagged assume que os dois words do par estéreo devem carregar a **mesma tag** para serem classificados como `idle`, `bfpexp` ou `fft`. Quando isso não acontece, o par é tratado como inconsistente. Esse comportamento aparece no analisador e nos logs estruturados.  

### Evidência dos logs de debug

A sessão de debug foi executada com uma matriz de cenários que reaproveita a mesma captura bruta para comparação justa entre hipóteses de parsing. Os cenários incluíram:

* `strict_tags_shift30`
* `relaxed_tags_shift30`
* `relaxed_tags_shift29`

com:

* `rate=48000`
* `frame_bins=512`
* `payload_bits=18`
* `tag_idle=0`
* `tag_bfpexp=1`
* `tag_fft=2`
* `bfpexp_flag_line=none`

e usando o card ALSA `Google voiceHAT SoundCard HiFi`.   

O ponto mais importante é que **mudar `tag_shift` de 30 para 29 praticamente não alterou o padrão do erro**. Isso enfraquece muito a hipótese de que o problema principal seja apenas “tag shift errado”. Pelo contrário: o padrão dos três cenários é consistente com **desalinhamento estrutural do par left/right**.

Os resumos indicaram:

* `tag_mismatch` em escala muito alta,
* `reserved_nonzero_words` muito altos,
* `other` alto,
* `max_fft_run` extremamente baixo, da ordem de 3 ou 4, quando o esperado para uma rajada FFT correta seria um bloco muito maior, idealmente próximo de 512 words FFT coerentes.

Isso é forte evidência de que os words recebidos pelo host **não estão sendo agrupados em pares estéreo semanticamente corretos**. 

### Hipótese principal de causa raiz no RTL

A análise do transmissor Verilog indica que a atualização do payload/tag ativo para o próximo item está acontecendo na fronteira errada do frame I2S.

O comportamento esperado do enlace é:

* durante um frame estéreo I2S:

  * slot esquerdo transmite `left_word`
  * slot direito transmite `right_word`
* somente após concluir o par estéreo completo é que o transmissor deve avançar para o próximo item semântico.

O bug provável é que o RTL está carregando o próximo par **na transição após o slot esquerdo**, em vez de fazê-lo na transição correta que preserva a ordem left→right para o host. Como consequência, o fluxo observado pelo Raspberry Pi tende a ficar semanticamente embaralhado, produzindo algo mais próximo de:

* right do próximo item,
* depois left do mesmo item,

ou alguma forma equivalente de quebra na costura entre slots.

Para o ALSA e para o parser Python, isso destrói a interpretação do par estéreo. O host continua agrupando words em pares `[left, right]`, mas esses pares já chegam logicamente corrompidos. O parser tagged não tem como reconstruir corretamente um frame semântico a partir de pares que já nasceram trocados no nível do serializer. 

### Por que o problema não parece estar no parser Python

O módulo Python já possui duas abordagens:

1. modo sem tags, mais frágil, baseado em GPIO/contagem fixa;
2. modo tagged, semanticamente melhor, baseado em tag por word e reconstrução do frame. 

No modo tagged, o receiver:

* decodifica tag e payload de cada word,
* exige coerência entre left e right,
* ignora `idle`,
* reconhece `bfpexp`,
* e só aceita words `fft` como parte do frame.

Se os pares já chegam incoerentes, ele inevitavelmente acumula:

* `tag_mismatch`,
* transições espúrias,
* e runs FFT curtas.

O fato de o parser continuar “vendo” palavras e classificando algo não significa que ele esteja errado; significa que ele está recebendo um stream semanticamente ruim. A estrutura dos logs aponta mais para defeito no transmissor do que para defeito na lógica de parsing.  

### Sobre o `overrun`

O erro de `overrun` continua sendo um problema real, mas ele deve ser tratado como **questão secundária**, não como causa raiz principal da captura incorreta.

O logger CSV atual:

* escreve linha por linha,
* usa loop Python por frame,
* e força `flush()` a cada chunk,

o que pode induzir atraso suficiente para estourar o buffer do `arecord`. Isso explica bem overrun em testes de logging bruto. Porém, o padrão observado nos logs tagged vai além de simples lentidão: ele mostra incoerência estrutural do conteúdo recebido. Portanto, o overrun pode coexistir com o bug principal, mas não o explica sozinho.  

### Conclusão técnica atual

A melhor hipótese de causa raiz é:

> **o transmissor I2S da FPGA está trocando o payload/tag ativo na fronteira errada do frame estéreo, causando desalinhamento semântico entre os slots left e right vistos pelo Raspberry Pi.**

Esse erro explica de forma consistente:

* os altos valores de `tag_mismatch`,
* os altos valores de `reserved_nonzero_words`,
* os muitos eventos classificados como `other`,
* os blocos FFT muito curtos (`max_fft_run` muito baixo),
* e a incapacidade do receiver Python de reconstruir rajadas FFT longas e limpas.

### O que deve acontecer depois da correção

Após corrigir o RTL do transmissor, a expectativa para a mesma bateria de debug é:

* `tag_mismatch` próximo de zero;
* `reserved_nonzero_words` próximo de zero;
* `other` muito baixo;
* `fft_run_lengths` longos e coerentes;
* `max_fft_run` muito maior, idealmente compatível com a duração esperada da rajada FFT;
* e comportamento muito mais estável do parser tagged no Raspberry Pi.

### Prioridade de ação recomendada

1. Corrigir primeiro o transmissor Verilog para garantir que o avanço do par semântico aconteça na fronteira correta do frame I2S.
2. Reexecutar a matriz de debug com a mesma metodologia.
3. Só depois disso retomar o ajuste fino do logger Python e do tratamento de overrun.
4. Em seguida, endurecer o parser Python para tratar `tag_mismatch` como anomalia estrutural explícita, não apenas como categoria genérica.

---