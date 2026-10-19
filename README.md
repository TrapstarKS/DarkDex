# DarkDex

Suíte de debug para Roblox baseada no [New Dex](https://github.com/LorekeeperZinnia/Dex) (Moon / LorekeeperZinnia),
reescrita em módulos Luau e empacotada num único arquivo com [darklua](https://darklua.com).

## Executar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<usuario>/DarkDex/main/dist/DarkDex.lua"))()
```

Executar de novo substitui a instância anterior (GUIs e conexões são removidas).

## Desenvolvimento

Ferramentas: `aftman install` (darklua, selene, stylua, luau-lsp) e [Lune](https://lune-org.github.io/docs).

```sh
lune run scripts/dev        # servidor local: cada request gera um build novo
lune run scripts/dev build  # build único em dist/DarkDex.lua
./scripts/check.sh          # formatação, selene, luau-lsp, testes e build
```

Com o servidor rodando, no executor:

```lua
loadstring(game:HttpGet("http://127.0.0.1:7777/DarkDex.lua"))()
-- ou, sem HTTP (o build é copiado para os workspaces do MacSploit/Delta):
loadstring(readfile("DarkDex.lua"))()
```

Não é preciso commitar para testar: salve o arquivo e execute de novo.

## Estrutura

```
src/
  init.luau        entrada: destrói a instância anterior e chama Main.Init
  Core/            estado compartilhado (Context), ambiente do executor, settings,
                   API dump/ReflectionMetadata, menu, intro, ícones e Search/
  Lib/             componentes de UI (Window, ScrollBar, CodeFrame, ContextMenu...)
  Apps/            Explorer, Properties e ScriptViewer
tests/             testes offline (Lune) das partes puras
dist/DarkDex.lua   bundle gerado, não editar
```

## Busca do Explorer

Compatível com o filtro do Explorer do Studio, com autocomplete (↑/↓, Tab, Enter):

| Busca | Resultado |
| --- | --- |
| `Dog`, `"Red Team Spawn"` | nome contém o texto |
| `is:BasePart` | `IsA` |
| `c:Part`, `classname:Part` | classe exata |
| `tag:Interactable` | tag do CollectionService |
| `Anchored=true`, `Locked=t` | propriedade |
| `Transparency > 0.5`, `Health ~= 100` | operadores `= == ~= != > < >= <=` |
| `Position.X >= 10`, `Color.R > 200` | campo da propriedade (cor em 0-255) |
| `Color = "255, 0, 0"` | valor inteiro |
| `material=plas` | enum parcial (`material=Plastic` é exato) |
| `meshId=` | propriedade vazia |
| `workspace.Model.*`, `Cart.**` | caminho: `*` um nível, `**` qualquer profundidade |
| `a b`, `a and b`, `a or b`, `not a`, `( )` | combinações |
| `/remotes`, `/bindables`, `/players`, `/loadedmodules`, `/rad 50` | extras do DarkDex |

Atalhos com o mouse sobre o Explorer: Ctrl+C/X, Ctrl+Shift+V, Ctrl+D, Del, F2, Ctrl+G/U
e Ctrl+A (seleciona os resultados da busca). Ctrl+Shift+X foca a busca.
