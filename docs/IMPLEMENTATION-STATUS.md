# Solara Energia — status de implementação

Atualizado em 15/10/2026.

## Repositório e publicação

- Repositório: `matheusalvma-ui/gran-solare`, branch `main`.
- A interface expandida está em `index.html`.
- O deploy Vercel mais recente verificado está em estado `READY` e corresponde ao commit `d6d5dfbc018e6e5a95053bb1e90280dced284a46`.
- Projeto Supabase: `dbfxmjxigrjybxappxlj`.

## Migrações aplicadas ao Supabase

As versões abaixo constam no histórico remoto de migrações:
- `20261014114159_add_inverter_monitoring_foundation`
- `20261014120200_private_energy_bill_pdf_storage`
- `20261014140727_create_dashboard_company_metrics_view`
- `20261015105753_secure_multi_tenant_expand_saas_platform`
- `tighten_rls_and_index_saas_tables`
- `index_customer_assignment_fk`
- `scope_customer_portal_reads_to_tenant`

Mudanças desta implementação incluem as tabelas `saas_plans`, `saas_subscriptions`, `organization_settings`, `crm_tasks`, `proposals`, `contracts`, `maintenance_work_orders`, `notifications`, `audit_events`; campos auxiliares de clientes, usinas, faturas e telemetria; políticas RLS por empresa/perfil; índices para consultas e chaves estrangeiras; e a view `dashboard_company_metrics` configurada com `security_invoker=true`. Foi removido acesso `anon` à view.

A função Edge `invite-company-user` foi publicada com verificação JWT, validação do perfil chamador, vinculação do cliente à empresa e registro de auditoria. O segredo administrativo é lido apenas do ambiente da função.

## Telas incluídas na interface

Visão geral, monitoramento, análise energética, clientes, usinas, faturas, geração, CRM/leads, tarefas comerciais, propostas, contratos, chamados, manutenção, notificações, relatórios CSV, usuários/convites, integrações, configurações da organização, assinatura/plano, administração Solara e portal do cliente.

## O que já funciona e o que depende de configuração

A interface lê registros reais do Supabase e não preenche gráficos com números fictícios. Exportações de dados estão disponíveis em CSV. Os valores de geração dependem dos registros de geração e telemetria existentes. Campos que a API do fabricante não fornece permanecem vazios/indisponíveis.

Ainda requer trabalho de integração antes de ser considerado SaaS comercial completo:
- Conectar e homologar APIs reais de fabricantes/inversores, com sincronização no servidor e logs de qualidade.
- Configurar SMTP/redirects do Supabase e testar convites/recuperação de senha com contas reais.
- Ligar um provedor de cobrança por webhook autenticado para checkout, pagamento, reembolso, upgrade/downgrade e cancelamento.
- Gerador de PDF/Excel final, processamento/OCR de faturas, assinatura eletrônica e notificações por e-mail/WhatsApp.
- Adicionar e testar MFA, política de retenção/backups/recuperação e testes com duas ou mais empresas reais.
- Habilitar proteção contra senhas comprometidas no painel de Auth do Supabase. O advisor da data acima ainda sinalizava essa opção desativada.
- Validar todos os fluxos em navegador com usuários de cada perfil e verificar o nível de proteção do domínio público no Vercel.

## Antes de colocar clientes comerciais

Não marque uma assinatura como paga sem confirmação do processador de pagamentos. Não guarde credenciais de fabricante no HTML. Faça teste de separação entre pelo menos duas empresas e um portal de cliente antes de expor dados reais. A saída `READY` do Vercel indica que o deploy terminou, mas não substitui teste funcional da aplicação em navegador.
