# Solara Energia — status da implementação

Atualizado em 15/10/2026.

## Repositório e deploy

- Código: [GitHub — matheusalvma-ui/gran-solare](https://github.com/matheusalvma-ui/gran-solare), branch `main`.
- Aplicação: [https://gran-solare.vercel.app](https://gran-solare.vercel.app) (domínio de produção verificado no projeto Vercel).
- O deploy mais recente consultado durante esta implementação estava em estado `READY`; a compilação de produção é acionada pelos commits da branch `main`.
- Backend: Supabase project `dbfxmjxigrjybxappxlj`.
- A interface usa apenas a chave pública publishable no navegador; segredos administrativos ficam no ambiente da Edge Function.

## Banco de dados e segurança já aplicados

As migrações remotas registradas no projeto são:

- `20261014114159_add_inverter_monitoring_foundation`
- `20261014120200_private_energy_bill_pdf_storage`
- `20261014140727_create_dashboard_company_metrics_view`
- `20261015105753_secure_multi_tenant_expand_saas_platform`
- `20261015110537_tighten_rls_and_index_saas_tables`
- `20261015110615_index_customer_assignment_fk`
- `20261015110723_scope_customer_portal_reads_to_tenant`
- `20261015111000_expand_crm_pipeline_stages`
- `20261015111536_enforce_subscription_access_and_plan_limits`
- `20261015111839_make_company_access_helper_invoker_safe`

Novas estruturas incluem planos/assinaturas, configurações organizacionais, tarefas comerciais, propostas, contratos, ordens de manutenção, notificações e auditoria. Foram adicionados campos para endereço e metas das usinas, créditos/consumo tarifário das faturas e telemetria de inversores quando a fonte fornece esses valores.

A view `dashboard_company_metrics` usa `security_invoker=true`, sem leitura anônima. As políticas RLS restringem os registros por organização e perfil. O acesso do portal do cliente confere o vínculo com a empresa nas consultas de clientes, usinas, geração, faturas e chamados. Foram adicionadas políticas restritivas para bloquear dados operacionais quando a empresa está suspensa ou a assinatura está cancelada/suspensa. Os limites de usuários, clientes, usinas e integrações são aplicados no banco quando a empresa tem um plano vinculado com limites configurados. A verificação atual não encontrou políticas RLS sobrepostas.

A função Edge `invite-company-user` foi publicada com verificação JWT, checagem de perfil e empresa, validação do cliente antes de convidar perfis de cliente e registro de auditoria. A entrega dos convites e recuperação de senha depende do SMTP e dos redirects configurados no Supabase.

## Telas e fluxos presentes

- Login com carregamento, mensagens de erro, exibir/ocultar senha, recuperação de acesso e limitação visual temporária após falhas repetidas.
- Dashboard com indicadores calculados dos registros reais disponíveis.
- Monitoramento com leitura de telemetria e histórico de sincronização, quando existente.
- Clientes, usinas, faturas, geração e análise energética.
- CRM com funil e avanço de etapa; tarefas comerciais.
- Propostas, contratos e ordens de manutenção.
- Chamados, notificações e relatórios com exportação CSV.
- Usuários e convites; configurações da organização.
- Administração da plataforma para empresas e planos, além de vincular/administrar assinaturas.
- Portal do cliente com vínculo obrigatório por perfil.
- Edição de clientes, usinas, faturas, leads, tarefas, propostas, contratos e ordens de manutenção, sujeita a perfil e regras do banco.

Os gráficos e totais usam dados do Supabase. A interface não cria valores fictícios para preencher telas. A exportação funcional entregue é CSV compatível com Excel.

## Ainda necessário antes de vender comercialmente

1. **Proteção de senhas comprometidas:** o advisor do Supabase ainda reporta essa opção desativada. Habilitar no painel Supabase em Authentication → Settings → Password Security → Leaked Password Protection. Referência: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
2. **Integrações de inversores:** a base para integrações, dispositivos, telemetria e logs existe, mas falta conectar e homologar as APIs reais dos fabricantes e automatizar a sincronização no servidor. Frequência/medições dependerão de cada provedor.
3. **Cobrança real:** planos e assinaturas estão modelados e o status pode ser administrado; checkout, cobrança recorrente, pagamentos, reembolsos, prorrateio e cancelamentos automáticos requerem um provedor de pagamento e webhooks autenticados. Não se deve marcar pagamentos como confirmados manualmente.
4. **Documentos e comunicações:** OCR de PDFs escaneados, extração automatizada revisável, geração final de PDF/Excel, assinatura eletrônica, e-mail/WhatsApp e relatórios agendados dependem de serviços adicionais.
5. **Endurecimento operacional:** habilitar e testar MFA para administradores, SMTP/redirects, backups/recuperação, retenção/exclusão de dados e monitoramento de erros.
6. **Homologação funcional:** testar no navegador com contas reais de todos os perfis e ao menos duas empresas diferentes, incluindo tentativas explícitas de leitura cruzada. Os testes realizados nesta etapa foram estáticos/estruturais e de configuração; não substituem uma bateria completa de testes end-to-end com dados reais.
7. **Planos legados:** empresas sem assinatura vinculada continuam com o comportamento legado. Para aplicar limites contratados, vincule um plano e configure os limites correspondentes.

O estado `READY` do Vercel confirma que o deploy terminou; não garante por si só que todos os fluxos comerciais externos estão integrados ou homologados.
