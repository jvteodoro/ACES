# Proposta de correção — serializer I2S tagged do ACES

## Objetivo

Este documento propõe uma correção técnica para o problema mais provável identificado na investigação atual do ACES: a incompatibilidade entre o contrato temporal do serializer I2S da FPGA e a forma como o host (Raspberry Pi + ALSA + parser Python) agrupa os dados em pares estéreo.

A proposta é orientada a implementação e validação.

---

# 1. Problema que a correção quer resolver

A investigação da base de código mostrou um ponto crítico:

- a documentação de intenção do transmissor diz que cada frame I2S deve representar semanticamente:
  - `left = real`
  - `right = imag`
- porém, os testbenches ativos aceitam explicitamente que o stream do adapter comece/alinha em:
  - `right -> left`

Isso é perigoso para o host porque o ALSA entrega o stream como pares estéreo naturais:

```text
[left, right]
```

Se o serializer efetivamente troca o conteúdo ativo numa fronteira que faz o primeiro lock útil surgir em ordem semântica quebrada, o host pode observar pares como:

- `left` de um item,
- `right` do item seguinte,

ou ainda exigir descarte artificial de um primeiro slot/word para “alinhar” a interpretação.

Esse comportamento é compatível com os sintomas observados:

- `tag_mismatch` alto,
- `other` alto,
- rajadas FFT muito curtas,
- dificuldade de sincronização estável.

---

# 2. Meta da correção

A meta da correção é simples e objetiva:

> **garantir que cada frame estéreo semanticamente completo observado pelo host corresponda exatamente a um único item lógico do transmissor.**

Em termos práticos:

- o par ativo (`left`, `right`, `tag`) deve permanecer estável durante **um frame estéreo completo**,
- o avanço para o próximo item deve acontecer somente na fronteira correta entre frames,
- o host deve conseguir observar diretamente:

```text
left do item atual
right do item atual
```

sem precisar descartar slots iniciais ou depender de lock “right-first”.

---

# 3. Estratégia de correção proposta

## 3.1. Corrigir o ponto em que o `active_*` é atualizado

Hoje, o RTL parece trocar o conteúdo ativo numa borda que permite o efeito `right -> left` no início/alinhamento do stream.

A proposta é mudar o contrato interno para:

### Regra principal

**O registrador ativo de transmissão (`active_tag_r`, `active_left_r`, `active_right_r`) só pode ser atualizado na fronteira que antecede o início do slot esquerdo de um novo frame estéreo.**

Em outras palavras:

- o par ativo é carregado,
- o slot esquerdo transmite `active_left_r`,
- o slot direito transmite `active_right_r`,
- só depois o transmissor fica autorizado a carregar o próximo par.

---

## 3.2. Tornar explícita a noção de “frame estéreo completo”

Hoje o código opera principalmente com:

- `channel_r`
- `slot_bit_r`
- `frame_boundary`

A proposta é explicitar semanticamente dois eventos:

- **fim do slot direito**
- **início do slot esquerdo seguinte**

A lógica de carregamento do próximo item deve ficar ancorada em um desses eventos de forma inequívoca, e a documentação deve dizer isso claramente.

### Recomendação prática

Introduzir sinais internos conceituais como:

- `end_of_slot_w`
- `end_of_left_slot_w`
- `end_of_right_slot_w`
- `start_of_left_slot_w`

mesmo que sejam wires/conditions locais.

Isso reduz ambiguidade e evita que `channel_r` seja interpretado de forma errada em condições de transição.

---

## 3.3. Manter o par ativo estável durante o frame inteiro

A correção deve garantir esta propriedade:

### Invariante proposta

Se o host observar um par estéreo consecutivo pertencente ao mesmo frame I2S, então:

- ambos os words vieram do mesmo `active_tag_r`
- o word esquerdo veio do mesmo `active_left_r`
- o word direito veio do mesmo `active_right_r`

Ou seja, não pode existir atualização de `active_*` “no meio semântico” do frame.

---

# 4. Proposta de ajuste conceitual no RTL

## 4.1. Comportamento desejado

### Em vez de:

- atualizar o próximo conteúdo ativo numa borda que faz o stream efetivamente iniciar/alinhar em `right -> left`

### Fazer:

- concluir completamente o frame atual,
- só então promover `pending_*` para `active_*`,
- iniciar o próximo frame com o slot esquerdo do novo item.

---

## 4.2. Sequência desejada por janela

Para uma janela FFT, o comportamento desejado deve ser:

1. `BFPEXP` é carregado como item ativo
2. o host observa frames completos `BFPEXP`
3. depois cada bin FFT é carregado como item ativo
4. para cada bin:
   - `left = real`
   - `right = imag`
5. ao fim do último bin, a lógica volta para `IDLE` ou prepara o próximo `BFPEXP`

Sem nenhuma necessidade de compensação no lado do host.

---

# 5. Mudanças concretas recomendadas

## 5.1. Mudar a lógica de `frame_boundary`

A primeira mudança recomendada é revisar a condição que hoje decide quando o próximo conteúdo ativo pode ser carregado.

### Ação proposta

Substituir a lógica implícita baseada em:

```verilog
if (channel_r == 1'b0)
    frame_boundary = 1'b1;
```

por uma lógica semanticamente explícita que represente:

> “acabou o frame estéreo atual e o próximo ciclo de serialização vai começar pelo slot esquerdo do próximo frame”.

### Requisito

A condição deve ser escolhida de modo que o próximo `active_*` seja visível primeiro no **left slot** do novo frame.

---

## 5.2. Atualizar o monitor dos testbenches

Os testbenches atuais foram escritos para aceitar o comportamento problemático.

### Ações propostas

#### Em `tb/unit/tb_i2s_fft_tx_adapter.sv`

- remover a lógica/comentário que aceita:
  - “o stream começa em right->left”
  - “o primeiro left precisa ser descartado”
- exigir que o primeiro frame útil completo já seja semanticamente válido

#### Em `tb/integration/tb_fft_tx_i2s_link.sv`

- remover a tolerância equivalente na integração
- fazer o monitor montar os pares assumindo o contrato correto desde o primeiro frame útil completo

### Resultado esperado

Se a correção estiver certa, o testbench deve passar **sem hacks de descarte inicial**.

---

## 5.3. Atualizar a documentação do contrato

### Arquivos a atualizar

- `docs/i2s_fft_tx_adapter.md`
- eventualmente `docs/architecture.md`
- qualquer documento do host-side que descreva o framing tagged

### O que explicitar

- em que fronteira o serializer troca de item ativo
- qual slot do frame vê primeiro o novo item
- que o contrato observado pelo host é diretamente:

```text
left = real
right = imag
```

sem ressalvas de lock inicial right-first.

---

# 6. Testes obrigatórios após a correção

## Teste A — unit test do serializer

### Objetivo

Provar que o primeiro frame útil completo já é semanticamente correto.

### Checklist

- [ ] remover descarte artificial de primeiro left/right
- [ ] verificar igualdade de tag entre canais
- [ ] verificar `left = expected_left`
- [ ] verificar `right = expected_right`
- [ ] verificar BFPEXP seguido por FFT sem quebra de alinhamento

### Critério de aceite

- o testbench deve passar sem comentários/lógica de tolerância a `right -> left`

---

## Teste B — integração FIFO -> serializer

### Objetivo

Garantir que a correção do serializer não quebre a integração com a FIFO de bridge.

### Checklist

- [ ] burst de bins continua sendo drenado corretamente
- [ ] ordem dos bins preservada
- [ ] `bfpexp`, `real`, `imag` continuam alinhados
- [ ] nenhum overflow espúrio aparece
- [ ] frames observados no monitor já saem semanticamente corretos

### Critério de aceite

- o testbench de integração passa sem lógica de “primeiro left sem right correspondente”

---

## Teste C — replay da matriz de debug no host

### Objetivo

Verificar se a correção reduz os sintomas de stream semanticamente quebrado.

### Execução recomendada

```bash
./run_channel_debug_matrix.sh --seconds 8 --bfpexp-flag-line <linha_se_existir>
```

### Métricas esperadas após a correção

- `tag_mismatch` cai fortemente
- `other` cai fortemente
- `reserved_nonzero_words` cai fortemente
- `max_fft_run` sobe fortemente
- `top_fft_run_lengths` passam a refletir rajadas FFT longas/coerentes

---

## Teste D — parser normal com mismatch explícito

Mesmo que esta não seja a correção principal, recomenda-se validar junto:

### Checklist

- [ ] expor `tag_mismatch` no parser normal
- [ ] repetir replay de captura antiga e nova
- [ ] comparar distribuição de classes

### Objetivo

Separar melhor:

- falha de framing real
- resíduos `other`
- mismatch de canais

---

# 7. Critérios formais de aceitação da correção

A correção só deve ser considerada concluída se todos os itens abaixo forem verdadeiros.

## Critérios RTL

- [ ] o próximo item ativo só entra em vigor no início do slot esquerdo do novo frame
- [ ] `active_left_r` e `active_right_r` permanecem estáveis durante o frame completo
- [ ] o primeiro frame útil completo observado após lock é semanticamente válido

## Critérios de verificação

- [ ] unit test passa sem descarte artificial de slots
- [ ] integration test passa sem tolerância a `right -> left`
- [ ] docs refletem o novo contrato temporal corretamente

## Critérios host-side

- [ ] matriz de debug mostra queda clara de `tag_mismatch`
- [ ] `max_fft_run` cresce claramente
- [ ] `other` e `reserved_nonzero_words` reduzem fortemente
- [ ] recepção tagged fica previsível sem depender de heurísticas de alinhamento

---

# 8. Riscos e cuidados

## Risco 1 — corrigir o serializer e esquecer os testes

Se os testbenches continuarem normalizando `right -> left`, o repositório ficará inconsistente: o RTL muda, mas a cultura de verificação continua aceitando o contrato antigo.

## Risco 2 — corrigir só o parser Python

Isso pode mascarar sintomas, mas não resolve a raiz estrutural se o stream no fio continuar semanticamente ambíguo.

## Risco 3 — misturar correção estrutural com tuning de performance

É importante separar as frentes:

1. primeiro corrigir o contrato do stream,
2. depois medir de novo,
3. só então otimizar logger/overrun.

Senão os efeitos ficam misturados e o diagnóstico perde clareza.

---

# 9. Ordem de implementação recomendada

## Etapa 1

Corrigir o `i2s_fft_tx_adapter.sv`.

## Etapa 2

Atualizar `tb_i2s_fft_tx_adapter.sv` e `tb_fft_tx_i2s_link.sv` para o novo contrato.

## Etapa 3

Atualizar `docs/i2s_fft_tx_adapter.md`.

## Etapa 4

Gerar novo bitstream e rodar a matriz de debug no Raspberry Pi.

## Etapa 5

Só depois disso, endurecer parser Python e otimizar logger.

---

# 10. Conclusão

A correção proposta é conceitualmente simples, mas arquiteturalmente importante:

> **o serializer deve apresentar ao host frames estéreo semanticamente completos, e não exigir lock/tolerância baseada em sequência `right -> left`.**

Se implementada corretamente, essa mudança deve:

- alinhar o comportamento real do RTL com a documentação de intenção,
- simplificar o contrato host-side,
- reduzir drasticamente os sintomas observados nos logs tagged,
- e tornar o sistema muito mais previsível para depuração e operação.

Essa é, no momento, a correção de maior impacto técnico para estabilizar o caminho FPGA -> I2S -> Raspberry Pi.
