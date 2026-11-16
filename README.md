# Delta Store — E-commerce App (Flutter, Firebase & IBM Watson AI)

Aplicativo mobile de e-commerce de moda construído em **Flutter** com tema escuro Material 3, backend em **Firebase (Auth + Cloud Firestore)** e **Assistente Virtual (Chatbot) integrado ao IBM watsonx Assistant (API v2)** com fallback inteligente local.

---

## Funcionalidades

* **Catálogo e Filtros:** Listagem em grade com filtro por categorias (`todos`, `camisetas`, `blusas`, `calcas`, `coletes`).
* **Detalhes do Produto:** Seleção de tamanho, descrição, adição ao carrinho e favoritos.
* **Favoritos:** Sincronização em tempo real por usuário autenticado.
* **Carrinho e Checkout:** Controle de quantidade, remoção por deslize (*swipe*), aplicação de cupons de desconto (`coupons/{CODE}`) e fechamento de pedido em lote no Firestore.
* **Autenticação e Perfil:** Cadastro, login, edição de nome de exibição, redefinição de senha por e-mail e histórico de compras com status do pedido.
* **Assistente Virtual (IBM Watson AI):**
  * Integração pronta com a **API REST v2 do IBM watsonx Assistant** (gerenciamento automático de sessão, suporte a respostas de texto e botões/opções interativas).
  * Configuração flexível via `--dart-define`, diretamente em `lib/config/watson_config.dart`, ou pela **tela de configurações (ícone de engrenagem)** dentro do próprio chat.
  * **Fallback local automático:** Quando as credenciais do IBM Watson ainda não estão configuradas (ou sem acesso à nuvem), o assistente responde automaticamente usando dados reais do catálogo/pedidos e orientações da loja.

---

## Stack

* **Flutter** (Material 3, Dark Theme)
* **Firebase Auth** & **Cloud Firestore**
* **IBM watsonx Assistant** (REST API v2 via `http`)

---

## Telas

Home · Product Detail · Favorites · Cart (cupom) · Profile · Orders · Assistente Delta (Chatbot)

| Home | Detalhe | Carrinho |
|---|---|---|
| <img src="docs/screens/home_sem_conta.png" width="260" /> | <img src="docs/screens/produto.png" width="260" /> | <img src="docs/screens/carrinho.png" width="260" /> |

| Favoritos | Perfil |
|---|---|
| <img src="docs/screens/favoritos.png" width="260" /> | <img src="docs/screens/perfil.png" width="260" /> |

---

## Como rodar o projeto

1. **Flutter** 3.32.8+ (Dart SDK `^3.8.1`).
2. Adicione suas credenciais Firebase:
   * Android: `android/app/google-services.json`
3. Instale as dependências e rode:
   ```bash
   flutter pub get
   flutter run
   ```

### Conectando o Chatbot IBM watsonx Assistant

No painel da IBM Cloud (**watsonx Assistant** > *Assistant settings* > *API details*), obtenha `API Key`, `Service URL` e `Environment ID / Assistant ID` e execute o app passando:

```bash
flutter run \
  --dart-define=WATSON_API_KEY=sua_api_key \
  --dart-define=WATSON_SERVICE_URL=sua_service_url \
  --dart-define=WATSON_ASSISTANT_ID=seu_assistant_id
```

Também é possível colar esses 3 campos em tempo de execução clicando no ícone de **engrenagem** no topo da tela do **Assistente Delta**.

---

## Estrutura do Firestore

* `Products/{categoria}/items/{pid}` → `{ title, description, price, images[], sizes[] }`
* `users/{uid}/favorites/{categoria_pid}` → `{ category, pid }`
* `users/{uid}/cart/{categoria_pid_size}` → `{ category, pid, size, qty, addedAt }`
* `orders/{orderId}` → `{ clientId, products[], productsPrice, couponCode, discountPercent, discountValue, totalPrice, status, createdAt }`
* `coupons/{CODE}` → `{ percent: 10 }`

---

## Licença

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
