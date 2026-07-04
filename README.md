# Nova Vida RP

Servidor de GTA V Roleplay (FiveM) baseado em VRP com otimizações e novos recursos integrados.

---

## 🚀 Últimas Atualizações

### 📦 Adicionado: Ox Inventory (`ox_inventory`)
* **Descrição:** Sistema de inventário moderno, performático e seguro integrado ao framework da base.
* **Dependências:** `oxmysql`, `ox_lib`.
* **Configuração:** O arquivo `server.cfg` foi configurado para suportar o novo inventário e o caminho de imagens das UI.

### 🪂 Ajustado: Sistema de Airdrop (`airdrop`)
* **Descrição:** O recurso de airdrop (`resources/[scripts]/airdrop`) foi devidamente ajustado, estruturado e configurado para funcionamento correto na base, resolvendo problemas de carregamento e dependências de scripts e bibliotecas do framework.

---

## 🛠️ Requisitos & Dependências
Para o correto funcionamento dos novos sistemas, certifique-se de que os seguintes recursos estejam presentes e atualizados no servidor:
* **[oxmysql](https://github.com/overextended/oxmysql)** (necessário para a persistência de itens do inventário)
* **[ox_lib](https://github.com/overextended/ox_lib)** (biblioteca padrão para as interfaces e funções do inventário)
* **[PolyZone](https://github.com/mkafrin/PolyZone)** (utilizado para demarcação de zonas como as áreas de airdrop)

---

## 🚀 Inicialização
Para iniciar o servidor localmente, utilize o arquivo executável de lote na raiz:
```bash
server.bat
```
