# [NOME COMERCIAL DO PROJETO]

Breve descrição da finalidade do firmware, das principais funções implementadas e do equipamento no qual será utilizado.

> Antes de iniciar o desenvolvimento, substitua todos os campos entre colchetes pelas informações específicas do projeto.

---

## 1. Identificação do projeto

| Campo                       | Informação                                 |
| --------------------------- | ------------------------------------------ |
| Código do projeto           | `[XX.XX.XX.XX.XX.XXXX.XXXX]`               |
| Nome do repositório         | `[NOME PADRONIZADO DO REPOSITÓRIO]`        |
| Código da placa/equipamento | `[CÓDIGO]`                                 |
| Revisão atual da PCB        | `[Rev. X.Y]`                               |
| Última versão liberada      | `[PCB-Rev-X.Y_SW-vX.Y.Z]`                  |
| Status                      | `[DESENVOLVIMENTO / VALIDAÇÃO / LIBERADO]` |

---

## 2. Responsáveis

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/USUARIO_RESPONSAVEL">
        <img
          src="https://github.com/USUARIO_RESPONSAVEL.png"
          width="100px"
          alt="Foto do desenvolvedor responsável"
        />
        <br />
        <strong>[NOME DO RESPONSÁVEL]</strong>
      </a>
      <br />
      Desenvolvedor responsável
    </td>
    <td align="center">
      <a href="https://github.com/USUARIO_SUBSTITUTO">
        <img
          src="https://github.com/USUARIO_SUBSTITUTO.png"
          width="100px"
          alt="Foto do substituto para aprovação"
        />
        <br />
        <strong>[NOME DO SUBSTITUTO]</strong>
      </a>
      <br />
      Substituto para aprovação
    </td>
    <td align="center">
      <a href="https://github.com/USUARIO_VALIDACAO">
        <img
          src="https://github.com/USUARIO_VALIDACAO.png"
          width="100px"
          alt="Foto do responsável pela validação"
        />
        <br />
        <strong>[NOME DO RESPONSÁVEL]</strong>
      </a>
      <br />
      Responsável pela validação
    </td>
  </tr>
</table>

### Equipe de desenvolvimento

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/USUARIO_1">
        <img
          src="https://github.com/USUARIO_1.png"
          width="80px"
          alt="Foto do desenvolvedor"
        />
        <br />
        <strong>[NOME DO DESENVOLVEDOR]</strong>
      </a>
      <br />
      Desenvolvedor
    </td>
    <td align="center">
      <a href="https://github.com/USUARIO_2">
        <img
          src="https://github.com/USUARIO_2.png"
          width="80px"
          alt="Foto do desenvolvedor"
        />
        <br />
        <strong>[NOME DO DESENVOLVEDOR]</strong>
      </a>
      <br />
      Desenvolvedor
    </td>
    <td align="center">
      <a href="https://github.com/USUARIO_3">
        <img
          src="https://github.com/USUARIO_3.png"
          width="80px"
          alt="Foto do desenvolvedor"
        />
        <br />
        <strong>[NOME DO DESENVOLVEDOR]</strong>
      </a>
      <br />
      Desenvolvedor
    </td>
  </tr>
</table>

O **Desenvolvedor Responsável** é a referência técnica do firmware e deve aprovar os Pull Requests antes da integração às branches permanentes.

Quando o Pull Request for aberto pelo próprio Desenvolvedor Responsável, a aprovação deverá ser realizada pelo substituto designado ou por outro desenvolvedor tecnicamente habilitado.

Para adicionar ou remover membros, edite a tabela HTML acima. A imagem de perfil é carregada automaticamente pelo GitHub por meio do endereço:

```text
https://github.com/NOME_DO_USUARIO.png
```

---

## 3. Configuração do CODEOWNERS

Este repositório utiliza o arquivo:

```text
.github/CODEOWNERS
```

O arquivo `CODEOWNERS` define os usuários responsáveis pela revisão das alterações realizadas no projeto.

Como este repositório é utilizado como template, nenhum nome de usuário deve permanecer previamente definido no arquivo. Após a criação de um novo repositório, o responsável pela configuração deverá editar o arquivo `.github/CODEOWNERS` e informar os usuários responsáveis pelo projeto.

Exemplo de configuração:

```text
# Responsável por todo o repositório
* @USUARIO_RESPONSAVEL

# Responsáveis por áreas específicas
/src/ @USUARIO_FIRMWARE
/docs/ @USUARIO_DOCUMENTACAO
/testes/ @USUARIO_TESTES
/scripts/ @USUARIO_RESPONSAVEL
```

Os nomes devem corresponder exatamente aos usuários do GitHub que possuem acesso ao repositório.

Após criar um repositório a partir deste template:

1. Edite o arquivo `.github/CODEOWNERS`;
2. Substitua os valores de exemplo pelos usuários responsáveis;
3. Confirme que os usuários possuem acesso ao repositório;
4. Verifique se o ruleset da branch exige revisão dos Code Owners;
5. Remova as linhas de exemplo que não forem utilizadas.

> O arquivo `CODEOWNERS` indica quem deve revisar cada área do repositório. Para tornar a aprovação obrigatória, o ruleset da branch também deve exigir a revisão dos Code Owners.

---

## 4. Compatibilidade

| Revisão da PCB | Branch correspondente | Última versão liberada    | Status                         |
| -------------- | --------------------- | ------------------------- | ------------------------------ |
| `Rev. X.Y`     | `develop/pcb-rev-X.Y` | `[PCB-Rev-X.Y_SW-vX.Y.Z]` | `[ATIVA / VALIDAÇÃO / LEGADO]` |

A versão do firmware deve ser utilizada somente nas revisões de hardware indicadas nesta tabela.

Caso o projeto possua mais de uma revisão de PCB, deverá ser adicionada uma linha para cada revisão suportada.

---

## 5. Ambiente de desenvolvimento

| Item                         | Informação        |
| ---------------------------- | ----------------- |
| IDE                          | `[NOME E VERSÃO]` |
| Compilador/Toolchain         | `[NOME E VERSÃO]` |
| SDK/Framework                | `[NOME E VERSÃO]` |
| Sistema operacional validado | `[SISTEMA]`       |
| Programador/Debugger         | `[MODELO]`        |

Sempre que possível, registre as versões exatas das ferramentas utilizadas. Isso facilita a reprodução do ambiente de desenvolvimento e reduz incompatibilidades durante a compilação.

---

## 6. Dependências

| Dependência             | Versão     | Finalidade    |
| ----------------------- | ---------- | ------------- |
| `[BIBLIOTECA / PACOTE]` | `[VERSÃO]` | `[DESCRIÇÃO]` |
| `[BIBLIOTECA / PACOTE]` | `[VERSÃO]` | `[DESCRIÇÃO]` |

Não incluir senhas, chaves privadas, tokens, certificados privados ou credenciais diretamente no repositório.

Quando uma dependência exigir configuração local, utilize arquivos de exemplo, como:

```text
.env.example
config.example.h
secrets.example.json
```

Os arquivos contendo valores reais devem ser adicionados ao `.gitignore`.

---

## 7. Compilação e gravação

### 7.1 Compilação

```text
[COMANDO OU PROCEDIMENTO DE COMPILAÇÃO]
```

Informar:

* ferramenta utilizada;
* configuração de compilação;
* diretório de execução;
* arquivos gerados;
* parâmetros adicionais necessários.

### 7.2 Gravação

```text
[COMANDO OU PROCEDIMENTO DE GRAVAÇÃO]
```

Informar os parâmetros necessários, como:

* porta de comunicação;
* endereço de memória;
* velocidade de gravação;
* modelo do programador;
* arquivo utilizado;
* configuração de alimentação da placa.

---

## 8. Estrutura do repositório

Atualize a estrutura abaixo conforme as características do projeto:

```text
.
├── .github/
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── workflows/
├── docs/
├── scripts/
├── src/
├── testes/
├── .gitignore
├── CHANGELOG.md
├── LICENSE
└── README.md
```

| Diretório ou arquivo | Finalidade                                        |
| -------------------- | ------------------------------------------------- |
| `.github/`           | Configurações, templates e workflows do GitHub    |
| `docs/`              | Documentação técnica do projeto                   |
| `scripts/`           | Scripts auxiliares de desenvolvimento e automação |
| `src/`               | Código-fonte do firmware                          |
| `testes/`            | Procedimentos, arquivos e evidências de teste     |
| `CHANGELOG.md`       | Histórico das versões liberadas                   |
| `README.md`          | Informações gerais e instruções do projeto        |

---

## 9. Fluxo de desenvolvimento

O desenvolvimento deverá seguir, de forma geral, o seguinte fluxo:

```text
Branch temporária
        ↓
Pull Request
        ↓
Revisão técnica
        ↓
Aprovação do Code Owner
        ↓
Integração à branch permanente
        ↓
Validação
        ↓
Criação da tag de versão
```

Não realizar alterações diretamente nas branches permanentes, salvo quando expressamente autorizado pelo procedimento interno aplicável.

### Branches permanentes

```text
main
develop/pcb-rev-X.Y
```

### Branches temporárias

```text
feature/pcb-rev-X.Y/nome-da-funcionalidade
fix/pcb-rev-X.Y/descricao-da-correcao
test/pcb-rev-X.Y/descricao-do-teste
```

---

## 10. Versionamento

As versões liberadas devem seguir o padrão definido para o projeto.

```text
PCB-Rev-X.Y_SW-vX.Y.Z
```

Onde:

```text
X.Y   = revisão da PCB
X.Y.Z = versão do firmware
```

Antes da criação de uma tag de versão, confirmar:

* aprovação do Pull Request;
* conclusão dos testes aplicáveis;
* atualização da versão no código;
* atualização do `CHANGELOG.md`;
* atualização da versão indicada neste `README.md`;
* correspondência entre o firmware e a revisão da PCB.

---

## 11. Scripts auxiliares

Os scripts disponíveis no diretório `scripts/` são utilizados para automatizar atividades do fluxo de desenvolvimento, como criação de branches, validações, versionamento e geração de tags.

Antes da utilização:

1. Consulte a documentação do script;
2. Verifique os pré-requisitos;
3. Confirme as permissões de execução;
4. Revise os parâmetros informados;
5. Não execute scripts sem compreender as alterações que serão realizadas.

Exemplo de estrutura:

```text

scripts/

├── README.md

├── configurar-atalhos.sh

├── exportar-versao.sh                        

├── nova-branch.sh

├── nova-tag.sh

├── novo-commit.sh

└── novo-pr.sh

```

O arquivo `scripts/README.md` deverá apresentar a finalidade, os parâmetros e exemplos de utilização de cada script.

---

## 12. Configuração inicial do repositório

Após criar um novo repositório a partir deste template, realizar as seguintes configurações:

1. Alterar o nome e a descrição do projeto;
2. Preencher a identificação do projeto;
3. Adicionar os responsáveis e desenvolvedores;
4. Atualizar as fotos e os links dos perfis GitHub;
5. Configurar o arquivo `.github/CODEOWNERS`;
6. Confirmar o acesso dos usuários indicados no `CODEOWNERS`;
7. Importar ou configurar os rulesets de branches;
8. Importar ou configurar os rulesets de tags;
9. Configurar a branch padrão;
10. Revisar os workflows do GitHub Actions;
11. Atualizar o `.gitignore`;
12. Documentar o ambiente de desenvolvimento;
13. Registrar as dependências;
14. Informar o procedimento de compilação;
15. Informar o procedimento de gravação;
16. Remover os exemplos que não forem utilizados;
17. Realizar um teste completo do fluxo de Pull Request.

