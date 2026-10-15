import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "Método não permitido." });

  const authHeader = req.headers.get("Authorization") || "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return reply(401, { error: "Sessão não identificada." });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply(500, { error: "A configuração segura do servidor está incompleta." });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: callerData, error: callerError } = await admin.auth.getUser(jwt);
  if (callerError || !callerData.user) return reply(401, { error: "Sessão inválida ou expirada." });

  const { data: actor, error: actorError } = await admin
    .from("profiles")
    .select("id,company_id,role")
    .eq("id", callerData.user.id)
    .maybeSingle();
  if (actorError || !actor) return reply(403, { error: "Perfil administrativo não encontrado." });

  let payload: Record<string, unknown>;
  try { payload = await req.json(); } catch { return reply(400, { error: "Corpo da requisição inválido." }); }

  const email = String(payload.email || "").trim().toLowerCase();
  const fullName = String(payload.full_name || "").trim().slice(0, 160);
  const role = String(payload.role || "").trim();
  const requestedCompany = String(payload.company_id || "").trim();
  const customerId = payload.customer_id ? String(payload.customer_id).trim() : null;
  const allowedRoles = ["company_admin", "manager", "operator", "commercial", "financial", "support", "customer"];

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(400, { error: "Informe um e-mail válido." });
  if (!fullName) return reply(400, { error: "Informe o nome do usuário." });
  if (!allowedRoles.includes(role)) return reply(400, { error: "Perfil de acesso inválido." });

  let companyId = actor.company_id as string | null;
  if (actor.role === "platform_admin") {
    if (!requestedCompany) return reply(400, { error: "Selecione a empresa do usuário." });
    companyId = requestedCompany;
  } else if (!["company_admin", "manager"].includes(String(actor.role))) {
    return reply(403, { error: "Seu perfil não pode convidar usuários." });
  }

  if (!companyId) return reply(400, { error: "O administrador não está vinculado a uma empresa." });
  if (actor.role !== "platform_admin" && role === "company_admin" && actor.role !== "company_admin") {
    return reply(403, { error: "Somente o administrador da empresa pode convidar outro administrador." });
  }

  const { data: targetCompany, error: companyError } = await admin
    .from("companies").select("id,status").eq("id", companyId).maybeSingle();
  if (companyError || !targetCompany || !["active", "trial"].includes(String(targetCompany.status))) {
    return reply(400, { error: "A empresa não existe ou não pode receber novos usuários." });
  }

  if (role === "customer") {
    if (!customerId) return reply(400, { error: "Vincule o usuário a um cadastro de cliente." });
    const { data: customer, error: customerError } = await admin
      .from("customers").select("id").eq("id", customerId).eq("company_id", companyId).maybeSingle();
    if (customerError || !customer) return reply(400, { error: "O cliente selecionado não pertence a esta empresa." });
  }

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName },
  });
  if (inviteError || !invited.user) {
    return reply(400, { error: "Não foi possível enviar o convite. Verifique se o e-mail já possui conta e se o SMTP do Supabase está configurado." });
  }

  const { error: profileError } = await admin.from("profiles").insert({
    id: invited.user.id,
    company_id: companyId,
    customer_id: role === "customer" ? customerId : null,
    full_name: fullName,
    role,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return reply(500, { error: "O convite foi revertido porque não foi possível criar o perfil com segurança." });
  }

  await admin.from("audit_events").insert({
    company_id: companyId,
    actor_user_id: actor.id,
    action: "user.invited",
    resource_type: "profile",
    resource_id: invited.user.id,
    details: { role, email },
    outcome: "success",
  });

  return reply(200, {
    success: true,
    message: "Convite processado. A entrega do e-mail depende da configuração SMTP do Supabase.",
  });
});