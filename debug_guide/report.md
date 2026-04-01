# Relatório de investigação orientado à ação — ACES

## Escopo

Este documento consolida a investigação do problema atual no caminho:

```text
FPGA -> I2S -> Raspberry Pi -> ALSA/arecord -> logger/parser Python
```

Diferente da versão anterior, este relatório foi **validado contra a base de código do projeto**:

- RTL ativo em `rtl/`
- testbenches em `tb/`
- documentação em `docs/`
- código host-side em `submodules/ACES-RPi-interface/rpi3b_i2s_fft/`
- testes Python em `submodules/ACES-RPi-interface/tests/`

O objetivo agora é:

1. distinguir claramente o que está **confirmado em código** do que ainda é **hipótese**,
2. transformar o diagnóstico em um plano de ação,
3. propor testes e checklists diretamente executáveis.

---

# 1. Resumo executivo

## Conclusão principal

A investigação da base de código confirma que existe um **problema estrutural no contrato entre o serializer I2S da FPGA e a interpretação natural do host**.

O ponto mais forte é este:

> **o serializer `i2s_fft_tx_adapter` e seus testbenches assumem explicitamente que o stream começa e se alinha em `right -> left`, e não em um frame semanticamente natural `left -> right` como o host ALSA/Python tende a consumir.**

Isso não é apenas uma hipótese do relatório anterior. Está **explicitamente documentado no comportamento dos testbenches**.

## Consequência prática

Isso não prova sozinho, de forma matemática final, que todo o erro observado no Raspberry Pi venha apenas daí. Mas prova que:

- o caminho RTL atual tem uma característica de framing não convencional,
- essa característica é suficientemente forte para explicar os sintomas de:
  - `tag_mismatch` alto,
  - `other` alto,
  - rajadas FFT muito curtas,
  - dificuldade de reconstrução estável de pares tagged no host.

## Conclusão secundária

O problema de `overrun` no `arecord`/ALSA também é real, e o código do logger confirma isso como risco plausível:

- CSV linha por linha,
- `flush()` a cada chunk,
- `chunk_frames` default pequeno (`256`),
- alto overhead Python/I/O.

Mas a análise da base de código mostra que o `overrun` deve ser tratado como **problema secundário de robustez/performance**, não como a melhor explicação para a corrupção semântica observada no stream tagged.

---

# 2. O que foi verificado na base de código

## 2.1. Serializer RTL: `rtl/frontend/i2s_fft_tx_adapter.sv`

### Fatos confirmados

O módulo documenta que cada bin FFT deve ocupar um frame I2S com:

- `left = real`
- `right = imag`

Ele também define o packing esperado por word:

- 2 bits de tag
- bits reservados em zero
- payload signed nos bits baixos

Além disso, em `docs/i2s_fft_tx_adapter.md`, o contrato também é descrito dessa forma.

### Porém, o comportamento temporal real importa mais que a intenção

No RTL, a borda usada para `frame_boundary` é:

```verilog
if (slot_bit_r == I2S_SLOT_W-1) begin
    slot_bit_r <= '0;
    next_channel = ~channel_r;
    channel_r <= next_channel;

    if (channel_r == 1'b0)
        frame_boundary = 1'b1;
end
```

Esse detalhe é crítico: a troca do `active_*` ocorre numa fronteira associada ao fechamento do slot em que `channel_r == 0`.

Sozinho, isso já exigia análise cuidadosa. Mas o que realmente fecha o diagnóstico é o item seguinte.

---

## 2.2. Testbench unitário: `tb/unit/tb_i2s_fft_tx_adapter.sv`

### Fato confirmado em comentário explícito

O monitor do testbench contém o comentário:

> `O stream do adapter comeca em right->left.`

E logo em seguida:

> `O primeiro left capturado apos adquirir lock nao tem o right correspondente e precisa ser descartado.`

Isso muda muito a força do diagnóstico.

Não estamos mais dizendo apenas:

- “talvez o serializer esteja desalinhado”

Estamos dizendo:

- **o próprio testbench oficial foi escrito assumindo que o stream começa em `right->left`**.

Ou seja, o comportamento não convencional do serializer está **incorporado ao contrato de verificação atual**.

### Consequência técnica

Se o Raspberry Pi/ALSA agrupa naturalmente as palavras em pares `[left, right]`, mas o serializer efetivamente produz uma sequência cujo lock inicial é `right -> left`, então há uma chance muito alta de o host observar pares semanticamente quebrados, especialmente durante aquisição de lock, transições ou re-sincronizações.

---

## 2.3. Testbench de integração: `tb/integration/tb_fft_tx_i2s_link.sv`

O mesmo padrão aparece na integração:

> `O primeiro left apos o lock pode ficar sem right correspondente porque o serializador inicia em right.`

Isso confirma que o comportamento não é acidental no unit test. Ele está presente também no cenário integrado.

### Interpretação

A base de testes atual do projeto **aceita e normaliza** um comportamento que, do ponto de vista de um consumidor host padrão baseado em ALSA estéreo, é estruturalmente perigoso.

---

## 2.4. Host-side Python: `fpga_fft_adapter.py`

### Fatos confirmados

O receiver tagged faz exatamente isto:

- decodifica `tag` e `payload` por word,
- forma pares estéreo a partir do que chega do ALSA,
- chama `_pair_kind_and_payload(pair)`,
- se `tag_l != tag_r`, classifica como:

```python
return "other", (payload_l, payload_r)
```

Ou seja:

- **o receiver normal não preserva a categoria `tag_mismatch` como classe separada**,
- ele degrada pares inconsistentes para `other`.

### Consequência

Isso confirma uma afirmação importante do relatório anterior:

> o caminho normal do parser mascara parte do erro estrutural ao classificar mismatch simplesmente como `other`.

Isso não gera o bug, mas dificulta o diagnóstico.

---

## 2.5. Canal de debug: `analyzer_from_fpga_fft.py`

### Fatos confirmados

O modo de debug faz classificação mais rica:

- `_classify_debug_pair(...)` retorna:
  - `tag_mismatch`
  - `idle`
  - `bfpexp`
  - `fft`
  - `other`

E ainda conta:

- `reserved_nonzero_words`
- `transition_counts`
- `max_run_by_kind`
- `fft_run_lengths`

### Consequência

O relatório anterior estava correto ao dizer que:

- a matriz de debug é adequada para diferenciar hipóteses,
- os logs de debug são muito mais informativos do que o caminho normal de recepção.

---

## 2.6. Script de matriz de debug: `run_channel_debug_matrix.sh`

### Fatos confirmados

O script realmente foi construído para:

- fazer **uma única captura bruta compartilhada**,
- gerar **múltiplos replays/análises em cima da mesma captura**,
- testar cenários como:
  - `strict_tags_shift30`
  - `relaxed_tags_shift30`
  - `relaxed_tags_shift29`

### Consequência

A afirmação metodológica do relatório anterior também está correta:

> comparar múltiplos cenários sobre a mesma captura bruta é o procedimento certo para isolar hipótese de parsing vs. hipótese de transporte/serializer.

---

## 2.7. Logger CSV: `fft_i2s_logger.py`

### Fatos confirmados

O logger atual realmente faz:

- `read_exactly(...)`
- `decode_stereo_frames(...)`
- loop Python por frame
- `writer.writerow(...)` por frame
- `f_csv.flush()` a cada chunk

Além disso, o default é:

```python
--chunk-frames = 256
```

### Consequência

A suspeita de `overrun` por software pesado está **confirmada como plausível**. O logger é objetivamente custoso para uso contínuo em tempo real.

Não é uma especulação. Está no código.

---

## 2.8. Testes Python

### Fatos confirmados

Os testes existentes validam vários comportamentos úteis:

- parsing tagged,
- necessidade/opcionalidade de BFPEXP antes de FFT,
- re-sincronização após frame quebrado,
- logger CSV básico,
- geração do dry-run da matriz de debug.

### Limite importante

Os testes **não** parecem validar explicitamente um cenário “host ALSA consumindo um stream começando em right-first e sendo confundido por isso”.

Ou seja:

- a suite atual cobre bem a lógica local do parser,
- mas não fecha totalmente o loop entre **ordem de serialização RTL** e **agrupamento natural de estéreo no host**.

Esse gap precisa ser preenchido.

---

# 3. O que agora pode ser tratado como confirmado

## Confirmado

### C1. O logger pode causar overrun por excesso de overhead

Base de código confirma:

- CSV linha a linha
- `flush()` por chunk
- chunk pequeno por padrão

### C2. O parser normal mascara `tag_mismatch` como `other`

Confirmado em `fpga_fft_adapter.py`.

### C3. A matriz de debug é adequada e foi projetada para replay comparativo da mesma captura

Confirmado em `run_channel_debug_matrix.sh`.

### C4. O serializer/test contract atual aceita comportamento `right -> left` no lock/início do stream

Confirmado em:

- `tb/unit/tb_i2s_fft_tx_adapter.sv`
- `tb/integration/tb_fft_tx_i2s_link.sv`

Esse é o achado mais forte da investigação.

---

# 4. O que ainda é hipótese, mas agora muito melhor fundamentada

## Hipótese H1

> O problema principal observado no Raspberry Pi decorre de incompatibilidade entre o framing real do serializer I2S e a forma como o host ALSA/Python agrupa pares estéreo.

### Status

**Muito forte, mas ainda não 100% fechada experimentalmente**.

### Por que é forte

Porque agora sabemos que:

- o serializer/testbench assume `right -> left` na aquisição/lock,
- o host agrupa naturalmente `[left, right]`,
- os sintomas observados (`tag_mismatch`, `other`, rajadas curtas) são exatamente os esperados para um stream semanticamente quebrado na costura.

### O que falta para fechar de vez

Executar testes dirigidos que comparem:

- captura do serializer atual,
- captura após correção de framing,
- e verificar se os contadores colapsam como previsto.

---

# 5. Diagnóstico técnico consolidado

## Diagnóstico atual

O sistema apresenta **dois problemas distintos**:

### Problema A — robustez/performance de captura

No lado Raspberry Pi, há risco real de `overrun` por:

- logger pesado,
- alto custo de CSV,
- `flush()` excessivo,
- chunks pequenos.

### Problema B — semântica do stream I2S/tagged

No lado FPGA/host, há forte evidência de incompatibilidade entre:

- a forma como o serializer realmente entra/anda no framing (`right -> left` no lock/início),
- e a suposição do host de pares estéreo semanticamente estáveis `[left, right]`.

## Prioridade relativa

O **Problema B** deve ser tratado primeiro para diagnóstico estrutural.

Motivo:

- `overrun` atrapalha a captura,
- mas não explica sozinho os padrões estruturados dos logs tagged.

Já a hipótese de framing/desalinhamento explica diretamente:

- `tag_mismatch` alto,
- `other` alto,
- `reserved_nonzero_words` alto,
- `max_fft_run` muito baixo.

---

# 6. Plano de ação recomendado

## Fase 1 — fechar a hipótese estrutural do serializer

### Objetivo

Determinar experimentalmente se o framing atual `right -> left` é a causa dominante da quebra semântica no host.

### Ação 1.1 — criar teste RTL/host de contrato explícito

**Criar um teste novo** que valide a compatibilidade entre:

- ordem efetiva do serializer RTL,
- agrupamento estéreo consumido no host.

### Checklist

- [ ] adicionar um teste de contrato no lado Python ou cocotb/bench auxiliar
- [ ] gerar uma sequência tagged conhecida (`BFPEXP`, depois FFT)
- [ ] modelar o agrupamento como o ALSA entregaria ao Python
- [ ] verificar se o primeiro frame semanticamente completo é reconstruído sem descartar/metade de palavra
- [ ] falhar o teste se houver necessidade de “descartar primeiro left” para o host funcionar

### Critério de sucesso

- O host deve conseguir observar pares tagged semanticamente coerentes sem hacks de descarte inicial.

---

### Ação 1.2 — instrumentar o serializer para provar a ordem real de frame

### Checklist

- [ ] adicionar sinais de debug explícitos no testbench indicando:
  - `active_tag_r`
  - `active_left_r`
  - `active_right_r`
  - `channel_r`
  - `slot_bit_r`
- [ ] registrar em log a primeira sequência completa de slots após reset
- [ ] documentar formalmente se a primeira emissão útil é `left->right` ou `right->left`
- [ ] remover ambiguidade entre “timing Philips I2S” e “ordem semântica do par entregue ao host” 

### Critério de sucesso

- Relatório/waveform demonstrando inequivocamente qual word o host verá como left e qual verá como right no primeiro frame útil.

---

### Ação 1.3 — corrigir o serializer para contrato semanticamente natural

Se os testes confirmarem que o host está de fato vendo pares semanticamente quebrados, a ação recomendada é corrigir o serializer para garantir:

```text
frame estéreo semântico = left do item atual + right do item atual
```

### Checklist

- [ ] revisar a lógica de `frame_boundary`
- [ ] revisar quando `active_*` é atualizado
- [ ] garantir que o par ativo permaneça estável por um frame estéreo inteiro
- [ ] atualizar unit test e integration test para rejeitar contrato `right->left`
- [ ] remover comentários que normalizam descarte do primeiro left/right como comportamento aceito
- [ ] atualizar `docs/i2s_fft_tx_adapter.md` com o contrato temporal correto

### Critério de sucesso

- testbenches passam sem lógica de “descartar primeiro left”
- stream observado no host reduz drasticamente `tag_mismatch`

---

## Fase 2 — repetir a matriz de debug no Raspberry Pi

### Objetivo

Comparar empiricamente o comportamento antes/depois da correção RTL.

### Teste recomendado

Rodar:

```bash
./run_channel_debug_matrix.sh --seconds 8 --bfpexp-flag-line <linha_se_existir>
```

### Checklist de execução

- [ ] registrar bitstream/commit RTL usado
- [ ] registrar wiring físico FPGA ↔ Pi
- [ ] registrar overlay usado no Pi
- [ ] guardar diretório completo `debug_runs/...`
- [ ] comparar `scenario_summary.tsv` antes/depois

### Métricas a observar

- [ ] `tag_mismatch`
- [ ] `other`
- [ ] `reserved_nonzero_words`
- [ ] `max_fft_run`
- [ ] `top_fft_run_lengths`

### Critério de sucesso esperado

Após correção do framing:

- [ ] `tag_mismatch` cai drasticamente
- [ ] `other` cai drasticamente
- [ ] `reserved_nonzero_words` cai drasticamente
- [ ] `max_fft_run` sobe fortemente, idealmente aproximando-se do tamanho esperado da rajada FFT

---

## Fase 3 — endurecer o parser host-side

Mesmo após correção RTL, o parser deveria ser melhorado para diagnóstico e robustez.

### Ação 3.1 — parar de esconder `tag_mismatch` como `other`

### Checklist

- [ ] alterar `_pair_kind_and_payload()` para retornar `tag_mismatch` explicitamente
- [ ] diferenciar `unknown_tag` de `tag_mismatch`
- [ ] refletir isso nos logs normais, não só no debug
- [ ] adicionar testes unitários para esse comportamento

### Critério de sucesso

- logs normais passam a denunciar mismatch estrutural claramente.

---

### Ação 3.2 — adicionar teste de regressão end-to-end do protocolo tagged

### Checklist

- [ ] gerar stream tagged sintético com idle, bfpexp e fft
- [ ] incluir cenário de desalinhamento left/right
- [ ] exigir que o parser detecte isso explicitamente
- [ ] incluir cenário corrigido e exigir frame FFT longo/coerente

### Critério de sucesso

- qualquer regressão futura no contrato do stream vira falha automática de teste.

---

## Fase 4 — corrigir o logger para reduzir overrun

Depois de estabilizar a semântica do stream, atacar performance do logger.

### Ação 4.1 — tornar o logger mais leve

### Checklist

- [ ] aumentar `--chunk-frames` default de `256` para algo como `1024` ou `2048` em testes
- [ ] remover `flush()` a cada chunk
- [ ] adicionar flush periódico (ex.: a cada N chunks)
- [ ] opcionalmente escrever buffer de linhas em lote
- [ ] opcionalmente criar modo binário/raw além do CSV

### Critério de sucesso

- redução clara de incidência de `overrun` em capturas longas.

---

### Ação 4.2 — separar captura de persistência

Se ainda houver overrun após simplificação do logger:

### Checklist

- [ ] capturar em thread/processo dedicado
- [ ] enfileirar chunks em memória
- [ ] escrever CSV/arquivo em consumidor separado
- [ ] medir tempo por chunk e backlog da fila

### Critério de sucesso

- consumo do `stdout` do `arecord` deixa de ser o gargalo dominante.

---

# 7. Testes concretos recomendados

## Teste T1 — validar contrato temporal do serializer

**Objetivo:** provar qual é a primeira sequência semanticamente observável no fio.

### Passos

- rodar `tb_i2s_fft_tx_adapter`
- registrar os primeiros 4 frames úteis completos
- anotar ordem semântica left/right observada

### Esperado se há problema estrutural

- necessidade de descartar frame/slot parcial para “alinhar” com a interpretação do host.

---

## Teste T2 — comparar antes/depois da correção RTL

**Objetivo:** medir efeito da mudança no serializer.

### Passos

- executar `run_channel_debug_matrix.sh` com bitstream atual
- corrigir serializer
- recompilar bitstream
- executar a mesma matriz novamente

### Métricas-chave

- `tag_mismatch`
- `other`
- `reserved_nonzero_words`
- `max_fft_run`

### Esperado após correção

- colapso de mismatch/other
- aumento forte de runs FFT longas

---

## Teste T3 — validar se parser mascarava o erro

**Objetivo:** confirmar que o receiver normal escondia mismatch como `other`.

### Passos

- alterar parser para expor `tag_mismatch`
- repetir replay de captura bruta antiga
- comparar distribuição de classes antes/depois

### Esperado

- parte relevante de `other` migra para `tag_mismatch`

---

## Teste T4 — isolar overrun do logger

**Objetivo:** verificar se overrun vem do logger/I/O.

### Passos

1. rodar `arecord` puro
2. rodar captura raw sem CSV
3. rodar logger CSV atual
4. rodar logger otimizado

### Checklist

- [ ] mesma taxa de amostragem
- [ ] mesma duração
- [ ] mesma configuração ALSA/device
- [ ] registrar ocorrência de overrun em cada modo

### Interpretação

- se só o CSV atual dá overrun, gargalo é software
- se todos dão overrun, revisar driver/overlay/clocks

---

# 8. Riscos de interpretação a evitar

## R1. Concluir cedo demais que “é só o parser”

A base de código enfraquece essa hipótese. O parser pode ser melhorado, mas há forte evidência de problema estrutural anterior ao parser.

## R2. Concluir cedo demais que “é só o logger”

O logger pode causar overrun, mas não explica bem a forma dos logs tagged.

## R3. Concluir sem teste que o serializer já está correto porque o doc diz `left=real/right=imag`

A documentação de intenção existe, mas os testbenches mostram que o contrato temporal efetivo é mais sutil — e provavelmente problemático para o host.

---

# 9. Checklist mestre

## Bloco A — fechar causa raiz estrutural

- [ ] criar teste explícito de compatibilidade serializer ↔ host
- [ ] provar ordem temporal semântica real do serializer
- [ ] corrigir framing se necessário
- [ ] atualizar docs
- [ ] atualizar testbenches para o novo contrato

## Bloco B — validar no Raspberry Pi

- [ ] rodar matriz de debug antes/depois
- [ ] salvar `debug_runs/`
- [ ] comparar `scenario_summary.tsv`
- [ ] registrar bitstream, wiring e overlay

## Bloco C — melhorar parser

- [ ] expor `tag_mismatch` explicitamente
- [ ] criar teste end-to-end do protocolo tagged
- [ ] endurecer tratamento de erro de framing

## Bloco D — melhorar logger

- [ ] aumentar chunk size
- [ ] remover flush por chunk
- [ ] testar modo raw/binário
- [ ] separar captura de persistência se necessário

---

# 10. Conclusão final

Após investigar a base de código completa, a versão refinada do diagnóstico é esta:

1. **O problema de overrun é real e tem suporte claro no código do logger.**
2. **Mas o achado mais importante está no serializer/test contract do I2S TX.**
3. Os testbenches oficiais confirmam que o stream do adapter pode começar/alinha em **`right -> left`**, e isso é um forte candidato a quebrar a interpretação do host baseada em pares estéreo naturais.
4. Portanto, a prioridade técnica correta agora é:

```text
primeiro fechar/corrigir o contrato temporal do serializer,
depois repetir a matriz de debug,
e só então otimizar logger/performance.
```

Se essa sequência for seguida, o projeto deve conseguir separar com clareza:

- erro estrutural de framing,
- erro de parsing/diagnóstico,
- e erro de performance de captura.

Esse é o caminho mais curto para transformar o problema atual em um sistema verificável e estável.
