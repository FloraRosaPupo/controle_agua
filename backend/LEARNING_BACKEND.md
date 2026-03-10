# 🎓 Aprendendo Backend: O Guia para Iniciantes!

Se você está começando agora, não se preocupe! O Backend parece assustador porque não tem botões coloridos como o App, mas a lógica é muito parecida com uma conversa.

---

## 💬 1. O que é um Endpoint?

Imagine que o seu **App (Frontend)** é uma pessoa e o **Servidor (Backend)** é uma biblioteca.

- O **App** chega na porta da biblioteca e diz: *"Oi! Quero ver os livros que li hoje"*.
- O **Endpoint** é justamente essa "porta" ou o "guichê" específico.
- A **URL** é o endereço: `meusite.com/agua/hoje`.

---

## 📋 2. Os 4 Verbos Principais (Métodos HTTP)

No backend, não usamos apenas um tipo de pedido. Usamos "verbos" para dizer o que queremos fazer:

1. **GET (Buscar)**: "Me mostra os dados?" (Ex: Ver o histórico).
2. **POST (Criar)**: "Guarda isso para mim?" (Ex: Registrei 300ml de água).
3. **PUT (Atualizar)**: "Muda isso aqui?" (Ex: Quero alterar minha meta de 2L para 3L).
4. **DELETE (Apagar)**: "Joga isso fora?" (Ex: Apaguei o registro que fiz errado).

---

## 🧩 3. Anatomia de um Pedido (Request)

Sempre que o App fala com o Backend, ele envia algumas coisas:

- **URL**: Onde ele está indo (`/water`).
- **Headers (Cabeçalhos)**: Informações extras (como o "Token" de segurança, que é o crachá de entrada).
- **Body (Corpo)**: Os dados reais. No caso da água, o corpo seria: `{ "amount": 250 }`.

---

## 🧪 4. Desafio Prático: Vamos criar um novo Endpoint juntos!

Vamos criar um endpoint para **ver o perfil do usuário**. É o jeito mais fácil de aprender.

### Passo A: Criar a Pasta/Arquivo
No seu projeto, as lógicas de usuário ficam em `src/auth.ts`. Vamos adicionar uma função lá.

### Passo B: Escrever o Código (A Lógica)
Adicione isso no final do arquivo `src/auth.ts`:

```typescript
export async function getProfile(req: AuthRequest, res: Response) {
    const userId = req.userId; // O middleware de segurança já nos dá quem é o usuário

    // O Prisma busca no banco de dados esse usuário específico
    const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { name: true, email: true, dailyGoal: true } // Não queremos enviar a senha!
    });

    res.json(user); // Entrega os dados pro App
}
```

### Passo C: Criar o "Caminho" (A Rota)
Abra o arquivo `src/routes.ts` e adicione a linha:

```typescript
router.get("/profile", authMiddleware, getProfile);
```

---

## 🚀 5. Como você testa se funcionou?

Como o backend não tem tela, usamos ferramentas para "fingir" que somos o App:

1. **Thunder Client**: É uma extensão dentro do VS Code.
2. Você cria uma requisição do tipo **GET**.
3. Coloca a URL: `http://localhost:3000/profile`.
4. Nos "Headers", você coloca a sua chave (Token).
5. Clica em **SEND** e vê a mágica acontecer!

---

**Dica de Ouro:** Não tente decorar tudo. O backend é como Lego: você entende como as peças se encaixam (Rota -> Lógica -> Banco de Dados) e depois é só repetir o processo para cada funcionalidade nova! 🧩✨
