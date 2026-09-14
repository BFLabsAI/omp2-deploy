# OMP2 — Oh My Pi com correção do Antigravity

Launcher side-by-side do [Oh My Pi](https://github.com/can1357/oh-my-pi) usando o código do PR que remove `requestType: "agent"` das requisições Google Antigravity.

O objetivo é manter o `omp` oficial intacto enquanto o upstream não publica uma release com a correção.

> **Estado do pin:** este repositório fixa o commit `b1ffa68caf746b41110ff978074a0faffb8d21de`, correspondente ao PR [#11742](https://github.com/can1357/oh-my-pi/pull/11742).
>
> O PR #11742 é a correção de protocolo: o cliente oficial do Antigravity omite `requestType: "agent"`, enquanto versões afetadas do OMP enviam esse campo e recebem um `429 RESOURCE_EXHAUSTED` falso, mesmo com quota disponível.

## O que é o `omp2`

O `omp2` **não é um fork parcial** e não substitui o `omp` global. Ele executa um checkout completo do OMP, fixado em um commit conhecido:

```text
omp   → instalação/release oficial
omp2  → checkout local do PR #11742
```

O launcher é apenas:

```text
bun /caminho/para/omp2-source/packages/coding-agent/src/cli.ts
```

Todo o restante do comportamento vem do OMP upstream naquele commit: ferramentas, modelos, autenticação, rotação de contas, sessões e configurações.

## O que é compartilhado com o `omp` oficial

Sem `--profile` e sem `PI_CODING_AGENT_DIR` customizado, os dois comandos usam os mesmos dados em `~/.omp/agent`:

- contas OAuth do Google Antigravity;
- `agent.db` e o pool de credenciais;
- tokens e refresh tokens armazenados pelo OMP;
- usage reports e estado persistido de rate limit;
- configurações globais em `~/.omp`;
- sessões e logs conforme o comando executado.

Uma conta adicionada com `omp` fica disponível para `omp2`, e vice-versa. Para garantir que uma sessão veja uma credencial recém-adicionada, encerre a sessão antiga e abra outra.

> **Segurança:** `agent.db` contém credenciais OAuth. Não faça commit, não envie esse arquivo para este repositório e não o copie entre VPSs sem transferência segura. A opção recomendada é fazer login novamente na VPS destino.

## Pré-requisitos

Para Linux x64:

- Git;
- Bun `>= 1.3.14`;
- `curl`;
- `tar`;
- acesso de rede ao GitHub e ao npm registry;
- uma instalação funcional de autenticação do OMP.

### Rust/Cargo é obrigatório?

Não para o fluxo deste repositório.

O instalador baixa o addon nativo Linux pré-compilado `@oh-my-pi/pi-natives-linux-x64@18.1.17` e o coloca no checkout local. Rust/Cargo só é necessário se você quiser recompilar o addon Rust `pi_natives` manualmente.

## Instalação em uma VPS

### 1. Instale Git e Bun

Use o método padrão da sua distribuição para instalar Git. Instale Bun conforme a documentação oficial:

```bash
curl -fsSL https://bun.sh/install | bash
source "$HOME/.bashrc"
```

Confirme:

```bash
git --version
bun --version
```

O instalador deste projeto não executa scripts externos de bootstrap além dos comandos que você chama explicitamente.

### 2. Obtenha este repositório

Se ele estiver hospedado em um repositório privado:

```bash
git clone <URL-DO-SEU-REPO-OMP2-DEPLOY> "$HOME/omp2-deploy"
cd "$HOME/omp2-deploy"
```

Se você transferir o diretório por `scp`/`rsync`, preserve os arquivos `README.md`, `VERSION`, `install.sh` e `omp2`.

### 3. Execute o instalador

```bash
cd "$HOME/omp2-deploy"
./install.sh
```

O instalador:

1. clona o repositório upstream do OMP em `~/.local/share/omp2/source`;
2. busca o ref do PR `pull/11742/head`;
3. verifica e faz checkout do commit fixado em `VERSION`;
4. instala as dependências com `bun install --frozen-lockfile`;
5. baixa o addon nativo Linux compatível com a versão do checkout;
6. instala o launcher em `~/.local/bin/omp2`.

Adicione o diretório ao `PATH` se necessário:

```bash
export PATH="$HOME/.local/bin:$PATH"
printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

### 4. Verifique a instalação

```bash
omp2 --version
git -C "$HOME/.local/share/omp2/source" rev-parse HEAD
```

O primeiro comando pode mostrar `omp/18.1.17`. Isso é a versão-base do pacote; o código executado continua sendo o commit fixado do PR.

O segundo deve mostrar:

```text
b1ffa68caf746b41110ff978074a0faffb8d21de
```

Confirme que o campo problemático não está mais sendo atribuído no provider principal:

```bash
grep -nE 'requestType[[:space:]]*:' \
  "$HOME/.local/share/omp2/source/packages/ai/src/providers/google-gemini-cli.ts"
```

O resultado esperado é vazio para a atribuição do envelope Antigravity. A interface antiga pode não existir mais nesse commit conforme a atualização do PR.

### 5. Faça um smoke test

```bash
omp2 -p --no-title \
  --model google-antigravity/gemini-3.8-flash \
  'Responda apenas: OMP2-INSTALADO-OK'
```

Resultado esperado:

```text
OMP2-INSTALADO-OK
```

Esse teste confirma o caminho completo: launcher, checkout local, dependências, addon nativo, autenticação e chamada Antigravity.

## Login de contas Antigravity

Use o `omp2` para adicionar uma conta:

```bash
omp2 auth-broker login google-antigravity
```

Repita para cada conta adicional.

Alternativamente, dentro de uma sessão interativa:

```text
/login
```

Selecione **Google Antigravity**.

Confira as contas e quotas:

```bash
omp2 usage --provider google-antigravity
```

Ou:

```bash
omp2 usage --json --provider google-antigravity
```

### VPS sem navegador

Em um servidor headless, o OMP pode tentar abrir a URL OAuth com `xdg-open` e falhar. Isso não significa que o OAuth esteja inválido.

Procedimento:

1. execute `omp2 auth-broker login google-antigravity` na VPS;
2. copie a URL OAuth exibida no terminal;
3. abra a URL em um navegador local autorizado;
4. conclua o consentimento;
5. cole o redirect URL/código quando o fluxo solicitar.

Nunca publique a URL OAuth, o código ou tokens em chat, issue ou log compartilhado.

## Uso diário

Entrar no modo interativo:

```bash
omp2
```

Enviar uma mensagem inicial:

```bash
omp2 'Analise este projeto e me diga por onde começar.'
```

Modo não interativo:

```bash
omp2 -p 'Responda apenas com OK.'
```

Escolher explicitamente o modelo:

```bash
omp2 --model google-antigravity/gemini-3.8-flash
```

O diretório atual continua sendo o diretório do terminal. O launcher não faz `cd` para dentro do checkout do OMP.

## Atualizar o pin

Não atualize automaticamente para `main`. O propósito deste repositório é reproduzir um commit conhecido.

Para trocar o commit:

1. altere somente `VERSION`;
2. confira que o commit contém a correção desejada;
3. execute `./install.sh`;
4. confirme o hash instalado;
5. rode o smoke test.

Exemplo de verificação:

```bash
EXPECTED="b1ffa68caf746b41110ff978074a0faffb8d21de"
ACTUAL="$(git -C "$HOME/.local/share/omp2/source" rev-parse HEAD)"
[[ "$ACTUAL" == "$EXPECTED" ]] && echo 'pin correto'
```

Se o checkout tiver alterações locais, o instalador para em vez de sobrescrevê-las. Para reinstalar um checkout descartável, remova apenas o source local depois de confirmar que não há alterações importantes:

```bash
rm -rf "$HOME/.local/share/omp2/source"
./install.sh
```

Não remova `~/.omp/agent` se quiser preservar contas e sessões.

## Quando o fix entrar no OMP oficial

Acompanhe:

- [PR #11742](https://github.com/can1357/oh-my-pi/pull/11742);
- [PR #11849](https://github.com/can1357/oh-my-pi/pull/11849);
- [PR #11884](https://github.com/can1357/oh-my-pi/pull/11884);
- [releases do OMP](https://github.com/can1357/oh-my-pi/releases).

Antes de aposentar o `omp2`, confirme na release que o código publicado não atribui mais `requestType: "agent"`:

```bash
gh api \
  'repos/can1357/oh-my-pi/contents/packages/ai/src/providers/google-gemini-cli.ts?ref=TAG' \
  --jq '.content' | base64 -d | grep -n 'requestType'
```

Depois:

```bash
omp update
omp --version
omp -p --no-title \
  --model google-antigravity/gemini-3.8-flash \
  'Responda apenas: OMP-OFICIAL-CORRIGIDO-OK'
```

Somente após validar o `omp` oficial, remova o launcher e o checkout:

```bash
rm -f "$HOME/.local/bin/omp2"
rm -rf "$HOME/.local/share/omp2/source"
```

## Troubleshooting

### `omp2: código local não encontrado`

O source ainda não foi instalado ou `OMP2_SOURCE_DIR` aponta para o lugar errado:

```bash
cd "$HOME/omp2-deploy"
./install.sh
```

### `Failed to load pi_natives native addon`

Reexecute:

```bash
cd "$HOME/omp2-deploy"
./install.sh
```

O instalador baixa os dois variantes do addon Linux x64. Cargo só é necessário se você escolher compilação local:

```bash
bun --cwd="$HOME/.local/share/omp2/source/packages/natives" run build
```

Esse comando exige Rust/Cargo e não faz parte do caminho padrão.

### `omp` falha, mas `omp2` funciona

Esse é o resultado esperado enquanto o `omp` oficial ainda estiver enviando o envelope antigo. Use `omp2` para sessões Antigravity.

### `omp2` também retorna 429

Verifique, nesta ordem:

```bash
git -C "$HOME/.local/share/omp2/source" rev-parse HEAD
omp2 usage --json --provider google-antigravity
```

Depois confirme:

- que o commit é o pin esperado;
- que a conta não está realmente sem quota;
- que não há uma sessão antiga usando o mesmo fluxo;
- que o endpoint não mudou upstream;
- que o erro é o `RESOURCE_EXHAUSTED` sem detalhes descrito em [#11689](https://github.com/can1357/oh-my-pi/issues/11689).

### OAuth tenta abrir navegador e falha

Use o procedimento de VPS headless acima. O problema é a ausência de um abridor de URL no servidor, não necessariamente a credencial.

### Contas não aparecem no `omp2`

Confirme que ambos usam o mesmo diretório de dados:

```bash
echo "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
```

Não use `--profile` em um comando e o perfil padrão no outro se a intenção for compartilhar contas.

## Rollback

O rollback não altera o `omp` oficial:

```bash
rm -f "$HOME/.local/bin/omp2"
rm -rf "$HOME/.local/share/omp2/source"
```

As contas em `~/.omp/agent` permanecem preservadas.

## Upstream

O código executado pertence ao projeto upstream:

- https://github.com/can1357/oh-my-pi
- https://github.com/can1357/oh-my-pi/pull/11742

Este repositório contém somente o pin operacional, o launcher e o instalador para reproduzir o ambiente corrigido.
