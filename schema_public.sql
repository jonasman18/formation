


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."statut_formation" AS ENUM (
    'brouillon',
    'publie',
    'archive'
);


ALTER TYPE "public"."statut_formation" OWNER TO "postgres";


CREATE TYPE "public"."type_lecon" AS ENUM (
    'video',
    'pdf',
    'texte'
);


ALTER TYPE "public"."type_lecon" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'apprenant',
    'formateur',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_cloturer_tentative"("p_id" "uuid", "p_reponses" "jsonb", "p_statut" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  t public.tentatives_examen;
  v_note integer;
  r record;
begin
  select * into t from public.tentatives_examen where id = p_id for update;
  if not found or t.statut <> 'en_cours' then
    return;
  end if;
  select note_min into v_note from public.quiz where id = t.quiz_id;
  select * into r from public._corriger_examen(t.quiz_id, p_reponses);
  update public.tentatives_examen
     set reponses = p_reponses,
         score = r.score,
         reussi = (r.score >= v_note),
         statut = p_statut,
         soumis_at = now()
   where id = p_id;
end
$$;


ALTER FUNCTION "public"."_cloturer_tentative"("p_id" "uuid", "p_reponses" "jsonb", "p_statut" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_corriger_examen"("p_quiz" "uuid", "p_reponses" "jsonb") RETURNS TABLE("bonnes" integer, "total" integer, "score" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with detail as (
    select
      q.id,
      coalesce((select array_agg(c.id order by c.id)
                  from public.choix c
                  join public.choix_corrects cc on cc.choix_id = c.id
                 where c.question_id = q.id), '{}'::uuid[]) as corrects,
      coalesce((select array_agg(distinct x::uuid order by x::uuid)
                  from jsonb_array_elements_text(
                         coalesce(p_reponses -> q.id::text, '[]'::jsonb)) x),
               '{}'::uuid[]) as donnes
    from public.questions q
    where q.quiz_id = p_quiz
  )
  select
    (count(*) filter (where cardinality(corrects) > 0 and corrects = donnes))::int,
    count(*)::int,
    case when count(*) = 0 then 0
         else round(100.0 * count(*) filter (where cardinality(corrects) > 0 and corrects = donnes)
                    / count(*))::int end
  from detail;
$$;


ALTER FUNCTION "public"."_corriger_examen"("p_quiz" "uuid", "p_reponses" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_expirer_tentatives"("p_user" "uuid", "p_quiz" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  t record;
begin
  for t in
    select id, reponses from public.tentatives_examen
     where apprenant_id = p_user and quiz_id = p_quiz and statut = 'en_cours'
       and limite_at + interval '30 seconds' < now()
  loop
    perform public._cloturer_tentative(t.id, t.reponses, 'expire');
  end loop;
end
$$;


ALTER FUNCTION "public"."_expirer_tentatives"("p_user" "uuid", "p_quiz" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_niveau_info"("p" integer) RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object('numero', n, 'nom', nom, 'seuil', seuil, 'suivant', suivant)
  from (
    select * from (values
      (1, 'Débutant', 0, 100),
      (2, 'Apprenti', 100, 300),
      (3, 'Confirmé', 300, 700),
      (4, 'Expert', 700, 1500),
      (5, 'Maître', 1500, null)
    ) as t(n, nom, seuil, suivant)
    where p >= seuil
    order by seuil desc
    limit 1
  ) x
$$;


ALTER FUNCTION "public"."_niveau_info"("p" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_niveau_info"("p" bigint) RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  select _niveau_info(least(p, 2000000000)::int)
$$;


ALTER FUNCTION "public"."_niveau_info"("p" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_prochaine_tentative"("p_user" "uuid", "p_quiz" "uuid") RETURNS timestamp with time zone
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v public.quiz;
  v_nb integer;
  v_debut timestamptz;
begin
  select * into v from public.quiz where id = p_quiz;
  select count(*), min(debut_at) into v_nb, v_debut
    from public.tentatives_examen
   where apprenant_id = p_user and quiz_id = p_quiz
     and debut_at > now() - make_interval(hours => v.delai_reprise_h);
  if v_nb >= v.max_tentatives then
    return v_debut + make_interval(hours => v.delai_reprise_h);
  end if;
  return null;
end
$$;


ALTER FUNCTION "public"."_prochaine_tentative"("p_user" "uuid", "p_quiz" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_changer_responsable"("p_formation" "uuid", "p_formateur" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not is_admin() then
    raise exception 'Non autorisé';
  end if;
  update formations set formateur_id = p_formateur where id = p_formation;
end;
$$;


ALTER FUNCTION "public"."admin_changer_responsable"("p_formation" "uuid", "p_formateur" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_lister_formations"() RETURNS TABLE("id" "uuid", "titre" "text", "statut" "text", "categorie" "text", "formateur_id" "uuid", "formateur_nom" "text", "nb_inscrits" bigint)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select f.id,
         f.titre,
         f.statut::text,
         c.nom,
         f.formateur_id,
         trim(coalesce(p.prenom, '') || ' ' || coalesce(p.nom, '')),
         (select count(*) from inscriptions i where i.formation_id = f.id)
  from formations f
  left join categories c on c.id = f.categorie_id
  left join profiles p on p.id = f.formateur_id
  where is_admin()
  order by f.created_at desc;
$$;


ALTER FUNCTION "public"."admin_lister_formations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_lister_utilisateurs"() RETURNS TABLE("id" "uuid", "nom" "text", "prenom" "text", "email" "text", "role" "public"."user_role", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not is_admin() then
    raise exception 'Accès refusé';
  end if;
  return query
    select p.id, p.nom, p.prenom, u.email::text, p.role, p.created_at
    from profiles p
    join auth.users u on u.id = p.id
    order by p.created_at desc;
end $$;


ALTER FUNCTION "public"."admin_lister_utilisateurs"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_role"("p_user" "uuid", "p_role" "public"."user_role") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not is_admin() then raise exception 'Accès refusé'; end if;
  update profiles set role = p_role where id = p_user;
end $$;


ALTER FUNCTION "public"."admin_set_role"("p_user" "uuid", "p_role" "public"."user_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_statistiques"("p_jours" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_debut timestamptz;
  v_pas text;
  v_fin timestamp;
  v_dep timestamp;
  v_serie jsonb;
begin
  if not public.is_admin() then
    raise exception 'Accès réservé à l''administrateur';
  end if;
  if p_jours is not null and p_jours < 1 then
    raise exception 'Période invalide';
  end if;

  v_debut := case when p_jours is null then null
                  else now() - make_interval(days => p_jours) end;
  v_pas := case when p_jours is not null and p_jours <= 90 then 'day' else 'month' end;
  v_fin := date_trunc(v_pas, now() at time zone 'Africa/Nairobi');

  if v_pas = 'day' then
    v_dep := v_fin - make_interval(days => p_jours - 1);
  elsif p_jours is null then
    v_dep := greatest(
      date_trunc('month',
        coalesce(least((select min(created_at) from public.inscriptions),
                       (select min(created_at) from public.profiles)), now())
        at time zone 'Africa/Nairobi'),
      v_fin - interval '23 months');
  else
    v_dep := greatest(
      date_trunc('month', v_fin - make_interval(days => p_jours)),
      v_fin - interval '23 months');
  end if;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'date', to_char(d, 'YYYY-MM-DD'),
             'inscriptions', coalesce(i.n, 0),
             'comptes', coalesce(c.n, 0))
           order by d), '[]'::jsonb)
    into v_serie
    from generate_series(
           v_dep, v_fin,
           case when v_pas = 'day' then interval '1 day' else interval '1 month' end) d
    left join (select date_trunc(v_pas, created_at at time zone 'Africa/Nairobi') as j,
                      count(*) as n
                 from public.inscriptions group by 1) i on i.j = d
    left join (select date_trunc(v_pas, created_at at time zone 'Africa/Nairobi') as j,
                      count(*) as n
                 from public.profiles group by 1) c on c.j = d;

  return jsonb_build_object(
    'utilisateurs', (
      select jsonb_build_object(
        'total', count(*),
        'apprenants', count(*) filter (where role = 'apprenant'),
        'formateurs', count(*) filter (where role = 'formateur'),
        'admins', count(*) filter (where role = 'admin'),
        'nouveaux', count(*) filter (where v_debut is null or created_at >= v_debut))
      from public.profiles),
    'formations', (
      select jsonb_build_object(
        'total', count(*),
        'publiees', count(*) filter (where statut = 'publie'),
        'brouillons', count(*) filter (where statut = 'brouillon'),
        'archivees', count(*) filter (where statut = 'archive'),
        'nouvelles', count(*) filter (where v_debut is null or created_at >= v_debut))
      from public.formations),
    'inscriptions', (
      select jsonb_build_object(
        'total', count(*),
        'periode', count(*) filter (where v_debut is null or created_at >= v_debut))
      from public.inscriptions),
    'certificats', (
      select jsonb_build_object(
        'total', count(*),
        'periode', count(*) filter (where v_debut is null or delivre_at >= v_debut))
      from public.certificats),
    'top_formations', coalesce((
      select jsonb_agg(jsonb_build_object('titre', t.titre, 'inscrits', t.n)
                       order by t.n desc, t.titre)
      from (select f.titre, count(*) as n
              from public.inscriptions i
              join public.formations f on f.id = i.formation_id
             where v_debut is null or i.created_at >= v_debut
             group by f.id, f.titre
             order by count(*) desc, f.titre
             limit 5) t), '[]'::jsonb),
    'pas', v_pas,
    'serie', v_serie
  );
end
$$;


ALTER FUNCTION "public"."admin_statistiques"("p_jours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."classement"("p_limite" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with t as (
    select
      vp.apprenant_id,
      vp.total,
      p.prenom,
      p.nom,
      p.avatar_url,
      rank() over (order by vp.total desc) as rg,
      row_number() over (order by vp.total desc, p.prenom, p.nom) as rn
    from v_points vp
    join profiles p on p.id = vp.apprenant_id
    where p.classement_visible and vp.total > 0
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'rang', rg,
    'nom', case
             when coalesce(trim(prenom), '') = '' then 'Apprenant'
             when coalesce(trim(nom), '') = '' then trim(prenom)
             else trim(prenom) || ' ' || upper(left(trim(nom), 1)) || '.'
           end,
    'avatar_url', avatar_url,
    'points', total,
    'niveau', _niveau_info(total)->>'nom',
    'moi', apprenant_id = auth.uid()
  ) order by rn), '[]'::jsonb)
  from t
  where rn <= least(greatest(p_limite, 1), 100)
$$;


ALTER FUNCTION "public"."classement"("p_limite" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."definir_classement_visible"("p_visible" boolean) RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update profiles set classement_visible = p_visible where id = auth.uid();
$$;


ALTER FUNCTION "public"."definir_classement_visible"("p_visible" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."definir_mon_avatar"("p_url" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  update public.profiles set avatar_url = p_url where id = auth.uid();
end
$$;


ALTER FUNCTION "public"."definir_mon_avatar"("p_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_f   formations%rowtype;
  v_nom text;
  v_n   int;
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;

  select * into v_f from formations where id = p_formation and statut = 'publie';
  if not found then
    raise exception 'Formation introuvable';
  end if;
  if v_f.acces <> 'sur_demande' then
    raise exception 'Cette formation est en inscription libre';
  end if;
  if est_inscrit(p_formation) then
    return 'inscrit';
  end if;

  insert into demandes_inscription (apprenant_id, formation_id, message)
  values (auth.uid(), p_formation, nullif(trim(coalesce(p_message, '')), ''))
  on conflict (apprenant_id, formation_id) do update
    set statut = 'en_attente',
        message = excluded.message,
        created_at = now(),
        traite_at = null,
        traite_par = null
    where demandes_inscription.statut <> 'en_attente';

  get diagnostics v_n = row_count;
  if v_n > 0 then
    select nullif(trim(coalesce(prenom, '') || ' ' || coalesce(nom, '')), '')
      into v_nom from profiles where id = auth.uid();

    insert into notifications (user_id, titre, corps)
    values (
      v_f.formateur_id,
      'Nouvelle demande d''inscription',
      coalesce(v_nom, 'Un apprenant') || ' demande à rejoindre « ' || v_f.titre || ' ».'
    );
  end if;

  return 'en_attente';
end $$;


ALTER FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."demarrer_examen"("p_formation" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
  v public.quiz;
  t public.tentatives_examen;
  v_pct numeric;
  v_prochaine timestamptz;
begin
  if uid is null then
    raise exception 'Non connecté';
  end if;
  select * into v from public.quiz
   where formation_id = p_formation and est_examen and publie;
  if not found then
    raise exception 'Aucun examen disponible pour cette formation';
  end if;
  if not public.est_inscrit(p_formation) then
    raise exception 'Inscription requise pour passer cet examen';
  end if;
  select pourcentage::numeric into v_pct from public.progression_formation
   where apprenant_id = uid and formation_id = p_formation;
  if coalesce(v_pct, 0) < 100 then
    raise exception 'Terminez d''abord toutes les leçons (progression à 100 %%)';
  end if;
  if not exists (select 1 from public.questions where quiz_id = v.id) then
    raise exception 'Cet examen ne contient pas encore de questions';
  end if;

  perform public._expirer_tentatives(uid, v.id);

  select * into t from public.tentatives_examen
   where apprenant_id = uid and quiz_id = v.id and statut = 'en_cours';

  if not found then
    if exists (select 1 from public.tentatives_examen
                where apprenant_id = uid and quiz_id = v.id and reussi) then
      raise exception 'Examen déjà réussi';
    end if;
    v_prochaine := public._prochaine_tentative(uid, v.id);
    if v_prochaine is not null then
      raise exception 'Nombre maximal de tentatives atteint. Réessayez après le %',
        to_char(v_prochaine at time zone 'Africa/Nairobi', 'DD/MM/YYYY "à" HH24:MI');
    end if;
    insert into public.tentatives_examen (quiz_id, apprenant_id, limite_at)
    values (v.id, uid, now() + make_interval(mins => v.duree_min))
    returning * into t;
  end if;

  return jsonb_build_object(
    'tentative_id', t.id,
    'limite_at', t.limite_at,
    'maintenant', now(),
    'titre', v.titre,
    'note_min', v.note_min,
    'duree_min', v.duree_min,
    'reponses', t.reponses,
    'questions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', q.id,
          'enonce', q.enonce,
          'choix', (select coalesce(jsonb_agg(
                       jsonb_build_object('id', c.id, 'texte', c.texte)
                       order by c.ordre, c.id), '[]'::jsonb)
                    from public.choix c where c.question_id = q.id)
        ) order by q.ordre)
      from public.questions q where q.quiz_id = v.id
    ), '[]'::jsonb)
  );
end
$$;


ALTER FUNCTION "public"."demarrer_examen"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enregistrer_examen"("p_formation" "uuid", "p_titre" "text", "p_note_min" integer, "p_duree_min" integer, "p_max_tentatives" integer, "p_delai_reprise_h" integer, "p_publie" boolean, "p_questions" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_id uuid;
  v_q uuid;
  v_c uuid;
  r record;
  s record;
  t record;
  v_nb_choix integer;
  v_nb_ok integer;
begin
  if not public.peut_gerer(p_formation) then
    raise exception 'Accès refusé';
  end if;
  if p_duree_min is null or p_duree_min < 1 then
    raise exception 'Durée invalide';
  end if;
  if p_max_tentatives is null or p_max_tentatives < 1 then
    raise exception 'Nombre de tentatives invalide';
  end if;
  if p_delai_reprise_h is null or p_delai_reprise_h < 1 then
    raise exception 'Délai de reprise invalide';
  end if;
  if jsonb_typeof(p_questions) <> 'array' then
    raise exception 'Questions invalides';
  end if;
  if p_publie and jsonb_array_length(p_questions) = 0 then
    raise exception 'Un examen publié doit contenir des questions';
  end if;

  select id into v_id from public.quiz where formation_id = p_formation and est_examen;

  if v_id is null then
    insert into public.quiz (module_id, formation_id, est_examen, titre, note_min,
                             duree_min, max_tentatives, delai_reprise_h, publie)
    values (null, p_formation, true, p_titre, p_note_min,
            p_duree_min, p_max_tentatives, p_delai_reprise_h, p_publie)
    returning id into v_id;
  else
    -- Corriger d'abord les tentatives dont le temps est écoulé.
    for t in
      select id, reponses from public.tentatives_examen
       where quiz_id = v_id and statut = 'en_cours'
         and limite_at + interval '30 seconds' < now()
    loop
      perform public._cloturer_tentative(t.id, t.reponses, 'expire');
    end loop;

    -- Un apprenant est encore en train de passer l'examen : on attend.
    if exists (select 1 from public.tentatives_examen
                where quiz_id = v_id and statut = 'en_cours') then
      raise exception 'Un apprenant est en train de passer l''examen : réessayez quand il aura terminé';
    end if;

    update public.quiz
       set titre = p_titre, note_min = p_note_min, duree_min = p_duree_min,
           max_tentatives = p_max_tentatives, delai_reprise_h = p_delai_reprise_h,
           publie = p_publie
     where id = v_id;
    delete from public.choix_corrects
     where choix_id in (select c.id from public.choix c
                          join public.questions q on q.id = c.question_id
                         where q.quiz_id = v_id);
    delete from public.choix
     where question_id in (select id from public.questions where quiz_id = v_id);
    delete from public.questions where quiz_id = v_id;
  end if;

  for r in
    select val, n from jsonb_array_elements(p_questions) with ordinality as t(val, n)
  loop
    select jsonb_array_length(r.val -> 'choix'),
           count(*) filter (where (x ->> 'correct')::boolean)
      into v_nb_choix, v_nb_ok
      from jsonb_array_elements(r.val -> 'choix') x;
    if v_nb_choix < 2 or v_nb_ok < 1 then
      raise exception 'Question % : au moins 2 choix et 1 bonne réponse', r.n;
    end if;

    insert into public.questions (quiz_id, enonce, ordre)
    values (v_id, r.val ->> 'enonce', r.n)
    returning id into v_q;

    for s in
      select val, n from jsonb_array_elements(r.val -> 'choix') with ordinality as t(val, n)
    loop
      insert into public.choix (question_id, texte, ordre)
      values (v_q, s.val ->> 'texte', s.n)
      returning id into v_c;
      if (s.val ->> 'correct')::boolean then
        insert into public.choix_corrects (choix_id) values (v_c);
      end if;
    end loop;
  end loop;

  return v_id;
end
$$;


ALTER FUNCTION "public"."enregistrer_examen"("p_formation" "uuid", "p_titre" "text", "p_note_min" integer, "p_duree_min" integer, "p_max_tentatives" integer, "p_delai_reprise_h" integer, "p_publie" boolean, "p_questions" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_quiz uuid;
  v_q uuid;
  v_c uuid;
  v_question jsonb;
  v_choix jsonb;
  v_i int := 0;
  v_nb_choix int;
  v_nb_corrects int;
begin
  if not peut_gerer(formation_de_module(p_module)) then
    raise exception 'Accès refusé';
  end if;
  if coalesce(trim(p_titre), '') = '' then
    raise exception 'Le titre du quiz est obligatoire';
  end if;
  if jsonb_array_length(coalesce(p_questions, '[]'::jsonb)) = 0 then
    raise exception 'Un quiz doit contenir au moins une question';
  end if;

  if p_quiz is null then
    insert into quiz (module_id, titre, note_min)
    values (p_module, trim(p_titre), p_note_min)
    returning id into v_quiz;
  else
    update quiz set titre = trim(p_titre), note_min = p_note_min
    where id = p_quiz and module_id = p_module
    returning id into v_quiz;
    if v_quiz is null then
      raise exception 'Quiz introuvable';
    end if;
    -- on remplace les questions (les tentatives passées sont conservées)
    delete from questions where quiz_id = v_quiz;
  end if;

  for v_question in select value from jsonb_array_elements(p_questions) loop
    v_i := v_i + 1;
    v_nb_choix := 0;
    v_nb_corrects := 0;

    insert into questions (quiz_id, enonce, ordre)
    values (v_quiz, trim(v_question->>'enonce'), v_i)
    returning id into v_q;

    for v_choix in select value from jsonb_array_elements(v_question->'choix') loop
      insert into choix (question_id, texte)
      values (v_q, trim(v_choix->>'texte'))
      returning id into v_c;
      v_nb_choix := v_nb_choix + 1;

      if coalesce((v_choix->>'correct')::boolean, false) then
        insert into choix_corrects (choix_id) values (v_c);
        v_nb_corrects := v_nb_corrects + 1;
      end if;
    end loop;

    if v_nb_choix < 2 then
      raise exception 'Question %: au moins 2 choix sont nécessaires', v_i;
    end if;
    if v_nb_corrects < 1 then
      raise exception 'Question %: cochez au moins une bonne réponse', v_i;
    end if;
  end loop;

  return v_quiz;
end $$;


ALTER FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enregistrer_reponses_examen"("p_tentative" "uuid", "p_reponses" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  update public.tentatives_examen
     set reponses = p_reponses
   where id = p_tentative
     and apprenant_id = auth.uid()
     and statut = 'en_cours'
     and limite_at + interval '30 seconds' >= now();
end
$$;


ALTER FUNCTION "public"."enregistrer_reponses_examen"("p_tentative" "uuid", "p_reponses" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."envoyer_push"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  begin
    perform net.http_post(
      url := 'https://plvyhaawrnylsmcckbyy.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', 'ce0r12n7aqb4t36mphu8zjisykfx9wlvgd5o'
      ),
      body := jsonb_build_object(
        'type', 'INSERT',
        'table', 'notifications',
        'record', to_jsonb(new)
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    -- un souci d'envoi ne doit jamais empêcher de créer la notification
    raise warning 'push non envoyé : %', sqlerrm;
  end;
  return new;
end $$;


ALTER FUNCTION "public"."envoyer_push"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."est_inscrit"("p_formation" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from inscriptions
                 where formation_id = p_formation and apprenant_id = auth.uid());
$$;


ALTER FUNCTION "public"."est_inscrit"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."est_proprietaire"("p_formation" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from formations
                 where id = p_formation and formateur_id = auth.uid());
$$;


ALTER FUNCTION "public"."est_proprietaire"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."formation_de_module"("p_module" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select formation_id from modules where id = p_module;
$$;


ALTER FUNCTION "public"."formation_de_module"("p_module" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into profiles (id, nom, prenom)
  values (new.id,
          new.raw_user_meta_data->>'nom',
          new.raw_user_meta_data->>'prenom');
  return new;
end $$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."infos_examen"("p_formation" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
  v public.quiz;
  v_utilisees integer;
  v_meilleure integer;
  v_reussi boolean;
  v_en_cours boolean;
  v_pct numeric;
  v_nbq integer;
begin
  if uid is null then
    raise exception 'Non connecté';
  end if;
  select * into v from public.quiz
   where formation_id = p_formation and est_examen and publie;
  if not found or not public.est_inscrit(p_formation) then
    return null;
  end if;
  perform public._expirer_tentatives(uid, v.id);

  select count(*) filter (where debut_at > now() - make_interval(hours => v.delai_reprise_h)),
         max(score),
         coalesce(bool_or(reussi), false),
         coalesce(bool_or(statut = 'en_cours'), false)
    into v_utilisees, v_meilleure, v_reussi, v_en_cours
    from public.tentatives_examen
   where apprenant_id = uid and quiz_id = v.id;

  select pourcentage::numeric into v_pct from public.progression_formation
   where apprenant_id = uid and formation_id = p_formation;
  select count(*) into v_nbq from public.questions where quiz_id = v.id;

  return jsonb_build_object(
    'titre', v.titre,
    'duree_min', v.duree_min,
    'note_min', v.note_min,
    'max_tentatives', v.max_tentatives,
    'delai_reprise_h', v.delai_reprise_h,
    'nb_questions', v_nbq,
    'tentatives_utilisees', v_utilisees,
    'meilleure_note', v_meilleure,
    'reussi', v_reussi,
    'en_cours', v_en_cours,
    'progression_ok', coalesce(v_pct, 0) >= 100,
    'prochaine_tentative',
      case when v_en_cours or v_reussi then null
           else public._prochaine_tentative(uid, v.id) end
  );
end
$$;


ALTER FUNCTION "public"."infos_examen"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_formateur"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from profiles where id = auth.uid() and role in ('formateur','admin'));
$$;


ALTER FUNCTION "public"."is_formateur"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lire_examen_edition"("p_formation" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v public.quiz;
begin
  if not public.peut_gerer(p_formation) then
    raise exception 'Accès refusé';
  end if;
  select * into v from public.quiz where formation_id = p_formation and est_examen;
  if not found then
    return null;
  end if;
  return jsonb_build_object(
    'id', v.id,
    'titre', v.titre,
    'note_min', v.note_min,
    'duree_min', v.duree_min,
    'max_tentatives', v.max_tentatives,
    'delai_reprise_h', v.delai_reprise_h,
    'publie', v.publie,
    'verrouille', exists (select 1 from public.tentatives_examen where quiz_id = v.id),
    'questions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'enonce', q.enonce,
          'choix', (select coalesce(jsonb_agg(
                       jsonb_build_object(
                         'texte', c.texte,
                         'correct', exists (select 1 from public.choix_corrects cc where cc.choix_id = c.id))
                       order by c.ordre, c.id), '[]'::jsonb)
                    from public.choix c where c.question_id = q.id)
        ) order by q.ordre)
      from public.questions q where q.quiz_id = v.id
    ), '[]'::jsonb)
  );
end
$$;


ALTER FUNCTION "public"."lire_examen_edition"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mes_points"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
  v v_points%rowtype;
  vis boolean;
  rang int;
  badges jsonb := '[]'::jsonb;
begin
  select * into v from v_points where apprenant_id = uid;
  if not found then
    return jsonb_build_object(
      'apprenant', false, 'points', 0, 'niveau', _niveau_info(0),
      'badges', '[]'::jsonb, 'rang', null, 'visible', true,
      'pts_lecons', 0, 'pts_quiz', 0, 'pts_examens', 0, 'pts_formations', 0
    );
  end if;

  select classement_visible into vis from profiles where id = uid;

  if vis and v.total > 0 then
    select 1 + count(*) into rang
    from v_points vp
    join profiles p on p.id = vp.apprenant_id
    where p.classement_visible and vp.total > v.total;
  end if;

  if v.pts_lecons > 0 then
    badges := badges || jsonb_build_array(jsonb_build_object(
      'code', 'premiere_lecon', 'titre', 'Première leçon',
      'description', 'Tu as terminé ta première leçon'));
  end if;
  if v.pts_quiz > 0 then
    badges := badges || jsonb_build_array(jsonb_build_object(
      'code', 'premier_quiz', 'titre', 'Premier quiz réussi',
      'description', 'Tu as réussi ton premier quiz'));
  end if;
  if v.pts_examens > 0 then
    badges := badges || jsonb_build_array(jsonb_build_object(
      'code', 'examen_reussi', 'titre', 'Examen réussi',
      'description', 'Tu as réussi un examen final'));
  end if;

  badges := badges || coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', 'formation_terminee', 'titre', 'Formation terminée',
      'description', f.titre) order by f.titre)
    from progression_formation pf
    join formations f on f.id = pf.formation_id
    where pf.apprenant_id = uid and pf.pourcentage >= 100
  ), '[]'::jsonb);

  badges := badges || coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', 'certifie', 'titre', 'Certifié',
      'description', f.titre) order by f.titre)
    from certificats c
    join formations f on f.id = c.formation_id
    where c.apprenant_id = uid
  ), '[]'::jsonb);

  return jsonb_build_object(
    'apprenant', true,
    'points', v.total,
    'pts_lecons', v.pts_lecons,
    'pts_quiz', v.pts_quiz,
    'pts_examens', v.pts_examens,
    'pts_formations', v.pts_formations,
    'niveau', _niveau_info(v.total),
    'badges', badges,
    'rang', rang,
    'visible', coalesce(vis, true)
  );
end;
$$;


ALTER FUNCTION "public"."mes_points"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."modifier_mon_profil"("p_nom" "text", "p_prenom" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  if length(trim(coalesce(p_nom, ''))) = 0
     or length(trim(coalesce(p_prenom, ''))) = 0 then
    raise exception 'Nom et prénom obligatoires';
  end if;
  update public.profiles
     set nom = trim(p_nom), prenom = trim(p_prenom)
   where id = auth.uid();
end
$$;


ALTER FUNCTION "public"."modifier_mon_profil"("p_nom" "text", "p_prenom" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notifier_correction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_titre text;
begin
  if new.corrige_at is not null
     and (old.corrige_at is null or old.note is distinct from new.note) then
    select titre into v_titre from exercices where id = new.exercice_id;
    insert into notifications (user_id, titre, corps)
    values (
      new.apprenant_id,
      'Exercice corrigé',
      'Votre exercice « ' || coalesce(v_titre, '') || ' » a été corrigé. Note : '
        || rtrim(rtrim(coalesce(new.note, 0)::text, '0'), '.') || ' / 20.'
    );
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."notifier_correction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."peut_gerer"("p_formation" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select is_admin() or est_proprietaire(p_formation);
$$;


ALTER FUNCTION "public"."peut_gerer"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."peut_lire"("p_formation" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select peut_gerer(p_formation) or est_inscrit(p_formation);
$$;


ALTER FUNCTION "public"."peut_lire"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proteger_role_formateur"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if old.role = 'formateur'
     and new.role is distinct from 'formateur'
     and exists (select 1 from formations where formateur_id = old.id) then
    raise exception
      'Ce formateur est responsable de formations : réaffectez-les d''abord';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."proteger_role_formateur"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."publier_annonce"("p_formation" "uuid", "p_titre" "text", "p_corps" "text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_titre_formation text;
  v_nb int;
begin
  if auth.uid() is null or not peut_gerer(p_formation) then
    raise exception 'Non autorisé';
  end if;

  if char_length(trim(coalesce(p_titre, ''))) not between 1 and 100 then
    raise exception 'Le titre doit faire entre 1 et 100 caractères';
  end if;
  if char_length(trim(coalesce(p_corps, ''))) not between 1 and 1000 then
    raise exception 'Le message doit faire entre 1 et 1000 caractères';
  end if;

  select titre into v_titre_formation from formations where id = p_formation;

  insert into annonces (formation_id, auteur_id, titre, contenu)
  values (p_formation, auth.uid(), trim(p_titre), trim(p_corps));

  insert into notifications (user_id, titre, corps)
  select i.apprenant_id,
         '📢 ' || trim(p_titre),
         v_titre_formation || ' : ' || left(trim(p_corps), 180)
  from inscriptions i
  where i.formation_id = p_formation;

  get diagnostics v_nb = row_count;
  return v_nb;
end;
$$;


ALTER FUNCTION "public"."publier_annonce"("p_formation" "uuid", "p_titre" "text", "p_corps" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;

  insert into device_tokens (user_id, token, plateforme)
  values (auth.uid(), p_token, p_plateforme)
  on conflict (token) do update
    set user_id = auth.uid(),
        plateforme = excluded.plateforme,
        updated_at = now();
end $$;


ALTER FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reserver_aux_apprenants"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if not exists (
    select 1 from profiles
    where id = new.apprenant_id and role = 'apprenant'
  ) then
    raise exception 'Seuls les apprenants peuvent s''inscrire à une formation';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."reserver_aux_apprenants"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."soumettre_examen"("p_tentative" "uuid", "p_reponses" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
  t public.tentatives_examen;
  v public.quiz;
  r record;
  v_nb integer;
begin
  select * into t from public.tentatives_examen
   where id = p_tentative and apprenant_id = uid;
  if not found then
    raise exception 'Tentative introuvable';
  end if;

  if t.statut = 'en_cours' then
    if now() <= t.limite_at + interval '30 seconds' then
      perform public._cloturer_tentative(t.id, coalesce(p_reponses, '{}'::jsonb), 'soumis');
    else
      perform public._cloturer_tentative(t.id, t.reponses, 'expire');
    end if;
    select * into t from public.tentatives_examen where id = p_tentative;
  end if;

  select * into v from public.quiz where id = t.quiz_id;
  select * into r from public._corriger_examen(t.quiz_id, t.reponses);
  select count(*) into v_nb from public.tentatives_examen
   where apprenant_id = uid and quiz_id = v.id
     and debut_at > now() - make_interval(hours => v.delai_reprise_h);

  return jsonb_build_object(
    'score', t.score,
    'reussi', t.reussi,
    'bonnes', r.bonnes,
    'total', r.total,
    'statut', t.statut,
    'note_min', v.note_min,
    'tentatives_restantes', greatest(v.max_tentatives - v_nb, 0),
    'prochaine_tentative',
      case when t.reussi then null
           else public._prochaine_tentative(uid, v.id) end
  );
end
$$;


ALTER FUNCTION "public"."soumettre_examen"("p_tentative" "uuid", "p_reponses" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_formation uuid;
  v_note_min  int;
  v_total     int;
  v_bonnes    int;
  v_score     int;
  v_reussi    boolean;
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;

  select formation_de_module(q.module_id), q.note_min
    into v_formation, v_note_min
  from quiz q
  where q.id = p_quiz_id;

  if v_formation is null then
    raise exception 'Quiz introuvable';
  end if;
  if not est_inscrit(v_formation) then
    raise exception 'Vous devez être inscrit à cette formation';
  end if;

  select count(*) into v_total from questions where quiz_id = p_quiz_id;
  if v_total = 0 then
    raise exception 'Ce quiz ne contient aucune question';
  end if;

  -- Une question est juste si l'ensemble des choix cochés
  -- est exactement l'ensemble des bons choix.
  select count(*) into v_bonnes
  from questions qu
  where qu.quiz_id = p_quiz_id
    and (
      select coalesce(array_agg(c.id order by c.id), '{}'::uuid[])
      from choix c
      join choix_corrects cc on cc.choix_id = c.id
      where c.question_id = qu.id
    ) = (
      select coalesce(array_agg(x.val::uuid order by x.val::uuid), '{}'::uuid[])
      from jsonb_array_elements_text(
             coalesce(p_reponses -> qu.id::text, '[]'::jsonb)
           ) as x(val)
    );

  v_score  := round(100.0 * v_bonnes / v_total);
  v_reussi := v_score >= v_note_min;

  insert into tentatives_quiz (quiz_id, apprenant_id, score, reussi)
  values (p_quiz_id, auth.uid(), v_score, v_reussi);

  return jsonb_build_object(
    'score', v_score, 'reussi', v_reussi, 'bonnes', v_bonnes, 'total', v_total
  );
end $$;


ALTER FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."supprimer_examen"("p_formation" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_id uuid;
begin
  if not public.peut_gerer(p_formation) then
    raise exception 'Accès refusé';
  end if;
  select id into v_id from public.quiz where formation_id = p_formation and est_examen;
  if v_id is null then
    return;
  end if;
  if exists (select 1 from public.tentatives_examen where quiz_id = v_id) then
    raise exception 'Des apprenants ont déjà passé cet examen : suppression impossible';
  end if;
  delete from public.choix_corrects
   where choix_id in (select c.id from public.choix c
                        join public.questions q on q.id = c.question_id
                       where q.quiz_id = v_id);
  delete from public.choix
   where question_id in (select id from public.questions where quiz_id = v_id);
  delete from public.questions where quiz_id = v_id;
  delete from public.quiz where id = v_id;
end
$$;


ALTER FUNCTION "public"."supprimer_examen"("p_formation" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  d       demandes_inscription%rowtype;
  v_titre text;
begin
  select * into d from demandes_inscription where id = p_demande;
  if not found then
    raise exception 'Demande introuvable';
  end if;
  if not peut_gerer(d.formation_id) then
    raise exception 'Accès refusé';
  end if;
  if d.statut <> 'en_attente' then
    raise exception 'Cette demande a déjà été traitée';
  end if;

  select titre into v_titre from formations where id = d.formation_id;

  update demandes_inscription
     set statut = case when p_accepter then 'acceptee' else 'refusee' end,
         traite_at = now(),
         traite_par = auth.uid()
   where id = p_demande;

  if p_accepter then
    insert into inscriptions (apprenant_id, formation_id)
    values (d.apprenant_id, d.formation_id)
    on conflict (apprenant_id, formation_id) do nothing;
  end if;

  insert into notifications (user_id, titre, corps)
  values (
    d.apprenant_id,
    case when p_accepter then 'Inscription acceptée' else 'Inscription refusée' end,
    case when p_accepter
      then 'Vous pouvez maintenant suivre « ' || v_titre || ' ».'
      else 'Votre demande pour « ' || v_titre || ' » n''a pas été acceptée.'
    end
  );
end $$;


ALTER FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verifier_responsable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if not exists (
    select 1 from profiles
    where id = new.formateur_id and role = 'formateur'
  ) then
    raise exception 'Le responsable d''une formation doit être un formateur';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."verifier_responsable"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."annonces" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "formation_id" "uuid" NOT NULL,
    "auteur_id" "uuid" NOT NULL,
    "titre" "text" NOT NULL,
    "contenu" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."annonces" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nom" "text" NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."certificats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "formation_id" "uuid" NOT NULL,
    "code" "text" DEFAULT "encode"("extensions"."gen_random_bytes"(6), 'hex'::"text") NOT NULL,
    "fichier_path" "text",
    "delivre_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."certificats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."choix" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question_id" "uuid" NOT NULL,
    "texte" "text" NOT NULL,
    "ordre" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."choix" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."choix_corrects" (
    "choix_id" "uuid" NOT NULL
);


ALTER TABLE "public"."choix_corrects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."demandes_inscription" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "formation_id" "uuid" NOT NULL,
    "statut" "text" DEFAULT 'en_attente'::"text" NOT NULL,
    "message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "traite_at" timestamp with time zone,
    "traite_par" "uuid",
    CONSTRAINT "demandes_inscription_statut_check" CHECK (("statut" = ANY (ARRAY['en_attente'::"text", 'acceptee'::"text", 'refusee'::"text"])))
);


ALTER TABLE "public"."demandes_inscription" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "plateforme" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "device_tokens_plateforme_check" CHECK (("plateforme" = ANY (ARRAY['android'::"text", 'ios'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."exercices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module_id" "uuid" NOT NULL,
    "titre" "text" NOT NULL,
    "consigne" "text",
    "date_limite" timestamp with time zone
);


ALTER TABLE "public"."exercices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."formations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "titre" "text" NOT NULL,
    "description" "text",
    "image_url" "text",
    "categorie_id" "uuid",
    "formateur_id" "uuid" NOT NULL,
    "statut" "public"."statut_formation" DEFAULT 'brouillon'::"public"."statut_formation" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "acces" "text" DEFAULT 'libre'::"text" NOT NULL,
    CONSTRAINT "formations_acces_check" CHECK (("acces" = ANY (ARRAY['libre'::"text", 'sur_demande'::"text"])))
);


ALTER TABLE "public"."formations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "formation_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."inscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lecons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module_id" "uuid" NOT NULL,
    "titre" "text" NOT NULL,
    "type" "public"."type_lecon" NOT NULL,
    "url" "text",
    "contenu" "text",
    "duree_sec" integer,
    "ordre" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."lecons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."modules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "formation_id" "uuid" NOT NULL,
    "titre" "text" NOT NULL,
    "ordre" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."modules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "titre" "text" NOT NULL,
    "corps" "text",
    "lue" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "nom" "text",
    "prenom" "text",
    "avatar_url" "text",
    "role" "public"."user_role" DEFAULT 'apprenant'::"public"."user_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "classement_visible" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."progression_lecons" (
    "apprenant_id" "uuid" NOT NULL,
    "lecon_id" "uuid" NOT NULL,
    "terminee_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."progression_lecons" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."progression_formation" WITH ("security_invoker"='true') AS
 SELECT "i"."apprenant_id",
    "i"."formation_id",
    "count"("l"."id") AS "total_lecons",
    "count"("p"."lecon_id") AS "lecons_terminees",
        CASE
            WHEN ("count"("l"."id") = 0) THEN (0)::numeric
            ELSE "round"(((100.0 * ("count"("p"."lecon_id"))::numeric) / ("count"("l"."id"))::numeric))
        END AS "pourcentage"
   FROM ((("public"."inscriptions" "i"
     JOIN "public"."modules" "m" ON (("m"."formation_id" = "i"."formation_id")))
     JOIN "public"."lecons" "l" ON (("l"."module_id" = "m"."id")))
     LEFT JOIN "public"."progression_lecons" "p" ON ((("p"."lecon_id" = "l"."id") AND ("p"."apprenant_id" = "i"."apprenant_id"))))
  GROUP BY "i"."apprenant_id", "i"."formation_id";


ALTER VIEW "public"."progression_formation" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quiz_id" "uuid" NOT NULL,
    "enonce" "text" NOT NULL,
    "ordre" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quiz" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module_id" "uuid",
    "titre" "text" NOT NULL,
    "note_min" integer DEFAULT 50 NOT NULL,
    "formation_id" "uuid",
    "est_examen" boolean DEFAULT false NOT NULL,
    "duree_min" integer,
    "max_tentatives" integer,
    "publie" boolean DEFAULT false NOT NULL,
    "delai_reprise_h" integer DEFAULT 24 NOT NULL,
    CONSTRAINT "quiz_note_min_check" CHECK ((("note_min" >= 0) AND ("note_min" <= 100))),
    CONSTRAINT "quiz_portee_chk" CHECK (((("module_id" IS NOT NULL) AND ("est_examen" = false)) OR (("module_id" IS NULL) AND "est_examen" AND ("formation_id" IS NOT NULL) AND ("duree_min" > 0) AND ("max_tentatives" > 0))))
);


ALTER TABLE "public"."quiz" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ressources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lecon_id" "uuid",
    "type" "text" NOT NULL,
    "titre" "text",
    "url" "text" NOT NULL,
    "ordre" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "exercice_id" "uuid",
    CONSTRAINT "ressources_parent_chk" CHECK ((((("lecon_id" IS NOT NULL))::integer + (("exercice_id" IS NOT NULL))::integer) = 1)),
    CONSTRAINT "ressources_type_check" CHECK (("type" = ANY (ARRAY['pdf'::"text", 'video'::"text"])))
);


ALTER TABLE "public"."ressources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."soumissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "exercice_id" "uuid" NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "contenu" "text",
    "fichier_path" "text",
    "note" numeric(5,2),
    "commentaire" "text",
    "soumis_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "corrige_at" timestamp with time zone,
    CONSTRAINT "soumissions_note_check" CHECK ((("note" >= (0)::numeric) AND ("note" <= (20)::numeric)))
);


ALTER TABLE "public"."soumissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tentatives_examen" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quiz_id" "uuid" NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "debut_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "limite_at" timestamp with time zone NOT NULL,
    "soumis_at" timestamp with time zone,
    "reponses" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "score" integer,
    "reussi" boolean,
    "statut" "text" DEFAULT 'en_cours'::"text" NOT NULL,
    CONSTRAINT "tentatives_examen_statut_check" CHECK (("statut" = ANY (ARRAY['en_cours'::"text", 'soumis'::"text", 'expire'::"text"])))
);


ALTER TABLE "public"."tentatives_examen" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tentatives_quiz" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quiz_id" "uuid" NOT NULL,
    "apprenant_id" "uuid" NOT NULL,
    "score" integer NOT NULL,
    "reussi" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tentatives_quiz" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_points" AS
 SELECT "p"."id" AS "apprenant_id",
    (COALESCE("l"."n", (0)::bigint) * 10) AS "pts_lecons",
    (COALESCE("q"."n", (0)::bigint) * 20) AS "pts_quiz",
    (COALESCE("e"."n", (0)::bigint) * 50) AS "pts_examens",
    (COALESCE("f"."n", (0)::bigint) * 100) AS "pts_formations",
    ((((COALESCE("l"."n", (0)::bigint) * 10) + (COALESCE("q"."n", (0)::bigint) * 20)) + (COALESCE("e"."n", (0)::bigint) * 50)) + (COALESCE("f"."n", (0)::bigint) * 100)) AS "total"
   FROM (((("public"."profiles" "p"
     LEFT JOIN ( SELECT "pl"."apprenant_id",
            "count"(*) AS "n"
           FROM ("public"."progression_lecons" "pl"
             JOIN "public"."lecons" "le" ON (("le"."id" = "pl"."lecon_id")))
          GROUP BY "pl"."apprenant_id") "l" ON (("l"."apprenant_id" = "p"."id")))
     LEFT JOIN ( SELECT "tq"."apprenant_id",
            "count"(DISTINCT "tq"."quiz_id") AS "n"
           FROM ("public"."tentatives_quiz" "tq"
             JOIN "public"."quiz" "z" ON (("z"."id" = "tq"."quiz_id")))
          WHERE ("tq"."reussi" AND (COALESCE("z"."est_examen", false) = false))
          GROUP BY "tq"."apprenant_id") "q" ON (("q"."apprenant_id" = "p"."id")))
     LEFT JOIN ( SELECT "tentatives_examen"."apprenant_id",
            "count"(DISTINCT "tentatives_examen"."quiz_id") AS "n"
           FROM "public"."tentatives_examen"
          WHERE "tentatives_examen"."reussi"
          GROUP BY "tentatives_examen"."apprenant_id") "e" ON (("e"."apprenant_id" = "p"."id")))
     LEFT JOIN ( SELECT "progression_formation"."apprenant_id",
            "count"(*) AS "n"
           FROM "public"."progression_formation"
          WHERE ("progression_formation"."pourcentage" >= (100)::numeric)
          GROUP BY "progression_formation"."apprenant_id") "f" ON (("f"."apprenant_id" = "p"."id")))
  WHERE ("p"."role" = 'apprenant'::"public"."user_role");


ALTER VIEW "public"."v_points" OWNER TO "postgres";


ALTER TABLE ONLY "public"."annonces"
    ADD CONSTRAINT "annonces_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_nom_key" UNIQUE ("nom");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."certificats"
    ADD CONSTRAINT "certificats_apprenant_id_formation_id_key" UNIQUE ("apprenant_id", "formation_id");



ALTER TABLE ONLY "public"."certificats"
    ADD CONSTRAINT "certificats_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."certificats"
    ADD CONSTRAINT "certificats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."choix_corrects"
    ADD CONSTRAINT "choix_corrects_pkey" PRIMARY KEY ("choix_id");



ALTER TABLE ONLY "public"."choix"
    ADD CONSTRAINT "choix_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."demandes_inscription"
    ADD CONSTRAINT "demandes_inscription_apprenant_id_formation_id_key" UNIQUE ("apprenant_id", "formation_id");



ALTER TABLE ONLY "public"."demandes_inscription"
    ADD CONSTRAINT "demandes_inscription_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."exercices"
    ADD CONSTRAINT "exercices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."formations"
    ADD CONSTRAINT "formations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inscriptions"
    ADD CONSTRAINT "inscriptions_apprenant_id_formation_id_key" UNIQUE ("apprenant_id", "formation_id");



ALTER TABLE ONLY "public"."inscriptions"
    ADD CONSTRAINT "inscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lecons"
    ADD CONSTRAINT "lecons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."progression_lecons"
    ADD CONSTRAINT "progression_lecons_pkey" PRIMARY KEY ("apprenant_id", "lecon_id");



ALTER TABLE ONLY "public"."questions"
    ADD CONSTRAINT "questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quiz"
    ADD CONSTRAINT "quiz_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ressources"
    ADD CONSTRAINT "ressources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."soumissions"
    ADD CONSTRAINT "soumissions_exercice_id_apprenant_id_key" UNIQUE ("exercice_id", "apprenant_id");



ALTER TABLE ONLY "public"."soumissions"
    ADD CONSTRAINT "soumissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tentatives_examen"
    ADD CONSTRAINT "tentatives_examen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tentatives_quiz"
    ADD CONSTRAINT "tentatives_quiz_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "certificats_apprenant_formation_uq" ON "public"."certificats" USING "btree" ("apprenant_id", "formation_id");



CREATE INDEX "demandes_formation_idx" ON "public"."demandes_inscription" USING "btree" ("formation_id", "statut");



CREATE INDEX "formations_categorie_id_idx" ON "public"."formations" USING "btree" ("categorie_id");



CREATE INDEX "formations_formateur_id_idx" ON "public"."formations" USING "btree" ("formateur_id");



CREATE INDEX "lecons_module_id_idx" ON "public"."lecons" USING "btree" ("module_id");



CREATE INDEX "modules_formation_id_idx" ON "public"."modules" USING "btree" ("formation_id");



CREATE INDEX "notifications_user_id_created_at_idx" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE UNIQUE INDEX "quiz_un_examen_par_formation" ON "public"."quiz" USING "btree" ("formation_id") WHERE "est_examen";



CREATE INDEX "ressources_lecon_id_idx" ON "public"."ressources" USING "btree" ("lecon_id");



CREATE UNIQUE INDEX "tentative_examen_unique_en_cours" ON "public"."tentatives_examen" USING "btree" ("quiz_id", "apprenant_id") WHERE ("statut" = 'en_cours'::"text");



CREATE OR REPLACE TRIGGER "demandes_apprenants_seulement" BEFORE INSERT ON "public"."demandes_inscription" FOR EACH ROW EXECUTE FUNCTION "public"."reserver_aux_apprenants"();



CREATE OR REPLACE TRIGGER "formations_responsable" BEFORE INSERT OR UPDATE OF "formateur_id" ON "public"."formations" FOR EACH ROW EXECUTE FUNCTION "public"."verifier_responsable"();



CREATE OR REPLACE TRIGGER "inscriptions_apprenants_seulement" BEFORE INSERT ON "public"."inscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."reserver_aux_apprenants"();



CREATE OR REPLACE TRIGGER "notifications_push" AFTER INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."envoyer_push"();



CREATE OR REPLACE TRIGGER "profiles_proteger_role" BEFORE UPDATE OF "role" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."proteger_role_formateur"();



CREATE OR REPLACE TRIGGER "soumissions_notifier" AFTER UPDATE ON "public"."soumissions" FOR EACH ROW EXECUTE FUNCTION "public"."notifier_correction"();



ALTER TABLE ONLY "public"."annonces"
    ADD CONSTRAINT "annonces_auteur_id_fkey" FOREIGN KEY ("auteur_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."annonces"
    ADD CONSTRAINT "annonces_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."certificats"
    ADD CONSTRAINT "certificats_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."certificats"
    ADD CONSTRAINT "certificats_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."choix_corrects"
    ADD CONSTRAINT "choix_corrects_choix_id_fkey" FOREIGN KEY ("choix_id") REFERENCES "public"."choix"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."choix"
    ADD CONSTRAINT "choix_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."demandes_inscription"
    ADD CONSTRAINT "demandes_inscription_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."demandes_inscription"
    ADD CONSTRAINT "demandes_inscription_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."demandes_inscription"
    ADD CONSTRAINT "demandes_inscription_traite_par_fkey" FOREIGN KEY ("traite_par") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."exercices"
    ADD CONSTRAINT "exercices_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."formations"
    ADD CONSTRAINT "formations_categorie_id_fkey" FOREIGN KEY ("categorie_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."formations"
    ADD CONSTRAINT "formations_formateur_id_fkey" FOREIGN KEY ("formateur_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."inscriptions"
    ADD CONSTRAINT "inscriptions_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inscriptions"
    ADD CONSTRAINT "inscriptions_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lecons"
    ADD CONSTRAINT "lecons_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."progression_lecons"
    ADD CONSTRAINT "progression_lecons_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."progression_lecons"
    ADD CONSTRAINT "progression_lecons_lecon_id_fkey" FOREIGN KEY ("lecon_id") REFERENCES "public"."lecons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."questions"
    ADD CONSTRAINT "questions_quiz_id_fkey" FOREIGN KEY ("quiz_id") REFERENCES "public"."quiz"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quiz"
    ADD CONSTRAINT "quiz_formation_id_fkey" FOREIGN KEY ("formation_id") REFERENCES "public"."formations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quiz"
    ADD CONSTRAINT "quiz_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ressources"
    ADD CONSTRAINT "ressources_exercice_id_fkey" FOREIGN KEY ("exercice_id") REFERENCES "public"."exercices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ressources"
    ADD CONSTRAINT "ressources_lecon_id_fkey" FOREIGN KEY ("lecon_id") REFERENCES "public"."lecons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."soumissions"
    ADD CONSTRAINT "soumissions_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."soumissions"
    ADD CONSTRAINT "soumissions_exercice_id_fkey" FOREIGN KEY ("exercice_id") REFERENCES "public"."exercices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tentatives_examen"
    ADD CONSTRAINT "tentatives_examen_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tentatives_examen"
    ADD CONSTRAINT "tentatives_examen_quiz_id_fkey" FOREIGN KEY ("quiz_id") REFERENCES "public"."quiz"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tentatives_quiz"
    ADD CONSTRAINT "tentatives_quiz_apprenant_id_fkey" FOREIGN KEY ("apprenant_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tentatives_quiz"
    ADD CONSTRAINT "tentatives_quiz_quiz_id_fkey" FOREIGN KEY ("quiz_id") REFERENCES "public"."quiz"("id") ON DELETE CASCADE;



ALTER TABLE "public"."annonces" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "annonces_select" ON "public"."annonces" FOR SELECT TO "authenticated" USING ("public"."peut_lire"("formation_id"));



CREATE POLICY "annonces_write" ON "public"."annonces" TO "authenticated" USING ("public"."peut_gerer"("formation_id")) WITH CHECK (("public"."peut_gerer"("formation_id") AND ("auteur_id" = "auth"."uid"())));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_admin" ON "public"."categories" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "categories_select" ON "public"."categories" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."certificats" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "certificats_select" ON "public"."certificats" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"("formation_id")));



ALTER TABLE "public"."choix" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."choix_corrects" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "choix_corrects_staff" ON "public"."choix_corrects" TO "authenticated" USING ("public"."is_formateur"()) WITH CHECK ("public"."is_formateur"());



CREATE POLICY "choix_select" ON "public"."choix" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."questions" "qu"
     JOIN "public"."quiz" "qz" ON (("qz"."id" = "qu"."quiz_id")))
  WHERE (("qu"."id" = "choix"."question_id") AND
        CASE
            WHEN "qz"."est_examen" THEN "public"."peut_gerer"("qz"."formation_id")
            ELSE "public"."peut_lire"("public"."formation_de_module"("qz"."module_id"))
        END))));



CREATE POLICY "choix_write" ON "public"."choix" USING ((EXISTS ( SELECT 1
   FROM ("public"."questions" "qu"
     JOIN "public"."quiz" "qz" ON (("qz"."id" = "qu"."quiz_id")))
  WHERE (("qu"."id" = "choix"."question_id") AND "public"."peut_gerer"(COALESCE("qz"."formation_id", "public"."formation_de_module"("qz"."module_id"))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."questions" "qu"
     JOIN "public"."quiz" "qz" ON (("qz"."id" = "qu"."quiz_id")))
  WHERE (("qu"."id" = "choix"."question_id") AND "public"."peut_gerer"(COALESCE("qz"."formation_id", "public"."formation_de_module"("qz"."module_id")))))));



CREATE POLICY "demandes_delete" ON "public"."demandes_inscription" FOR DELETE TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) AND ("statut" = 'en_attente'::"text")));



ALTER TABLE "public"."demandes_inscription" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "demandes_select" ON "public"."demandes_inscription" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"("formation_id")));



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_tokens_own" ON "public"."device_tokens" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."exercices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "exercices_select" ON "public"."exercices" FOR SELECT TO "authenticated" USING ("public"."peut_lire"("public"."formation_de_module"("module_id")));



CREATE POLICY "exercices_write" ON "public"."exercices" TO "authenticated" USING ("public"."peut_gerer"("public"."formation_de_module"("module_id"))) WITH CHECK ("public"."peut_gerer"("public"."formation_de_module"("module_id")));



ALTER TABLE "public"."formations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "formations_delete" ON "public"."formations" FOR DELETE TO "authenticated" USING ("public"."peut_gerer"("id"));



CREATE POLICY "formations_insert" ON "public"."formations" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_formateur"() AND (("formateur_id" = "auth"."uid"()) OR "public"."is_admin"())));



CREATE POLICY "formations_select" ON "public"."formations" FOR SELECT USING ((("statut" = 'publie'::"public"."statut_formation") OR ("formateur_id" = "auth"."uid"()) OR "public"."is_admin"() OR "public"."peut_gerer"("id")));



CREATE POLICY "formations_update" ON "public"."formations" FOR UPDATE TO "authenticated" USING ("public"."peut_gerer"("id")) WITH CHECK ("public"."peut_gerer"("id"));



ALTER TABLE "public"."inscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inscriptions_delete" ON "public"."inscriptions" FOR DELETE TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "inscriptions_insert" ON "public"."inscriptions" FOR INSERT TO "authenticated" WITH CHECK ((("apprenant_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."formations" "f"
  WHERE (("f"."id" = "inscriptions"."formation_id") AND ("f"."statut" = 'publie'::"public"."statut_formation") AND ("f"."acces" = 'libre'::"text"))))));



CREATE POLICY "inscriptions_select" ON "public"."inscriptions" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"("formation_id")));



ALTER TABLE "public"."lecons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lecons_select" ON "public"."lecons" FOR SELECT TO "authenticated" USING ("public"."peut_lire"("public"."formation_de_module"("module_id")));



CREATE POLICY "lecons_write" ON "public"."lecons" TO "authenticated" USING ("public"."peut_gerer"("public"."formation_de_module"("module_id"))) WITH CHECK ("public"."peut_gerer"("public"."formation_de_module"("module_id")));



ALTER TABLE "public"."modules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "modules_select" ON "public"."modules" FOR SELECT TO "authenticated" USING ("public"."peut_lire"("formation_id"));



CREATE POLICY "modules_write" ON "public"."modules" TO "authenticated" USING ("public"."peut_gerer"("formation_id")) WITH CHECK ("public"."peut_gerer"("formation_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_delete" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_select" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_update" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_admin_all" ON "public"."profiles" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) OR "public"."is_formateur"()));



CREATE POLICY "profiles_update_self" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "progression_delete" ON "public"."progression_lecons" FOR DELETE TO "authenticated" USING (("apprenant_id" = "auth"."uid"()));



CREATE POLICY "progression_insert" ON "public"."progression_lecons" FOR INSERT TO "authenticated" WITH CHECK ((("apprenant_id" = "auth"."uid"()) AND "public"."est_inscrit"(( SELECT "public"."formation_de_module"("l"."module_id") AS "formation_de_module"
   FROM "public"."lecons" "l"
  WHERE ("l"."id" = "progression_lecons"."lecon_id")))));



ALTER TABLE "public"."progression_lecons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "progression_select" ON "public"."progression_lecons" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"(( SELECT "public"."formation_de_module"("l"."module_id") AS "formation_de_module"
   FROM "public"."lecons" "l"
  WHERE ("l"."id" = "progression_lecons"."lecon_id")))));



ALTER TABLE "public"."questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "questions_select" ON "public"."questions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."quiz" "q"
  WHERE (("q"."id" = "questions"."quiz_id") AND
        CASE
            WHEN "q"."est_examen" THEN "public"."peut_gerer"("q"."formation_id")
            ELSE "public"."peut_lire"("public"."formation_de_module"("q"."module_id"))
        END))));



CREATE POLICY "questions_write" ON "public"."questions" USING ((EXISTS ( SELECT 1
   FROM "public"."quiz" "q"
  WHERE (("q"."id" = "questions"."quiz_id") AND "public"."peut_gerer"(COALESCE("q"."formation_id", "public"."formation_de_module"("q"."module_id"))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."quiz" "q"
  WHERE (("q"."id" = "questions"."quiz_id") AND "public"."peut_gerer"(COALESCE("q"."formation_id", "public"."formation_de_module"("q"."module_id")))))));



ALTER TABLE "public"."quiz" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "quiz_select" ON "public"."quiz" FOR SELECT USING (
CASE
    WHEN "est_examen" THEN ("public"."peut_gerer"("formation_id") OR ("publie" AND "public"."peut_lire"("formation_id")))
    ELSE "public"."peut_lire"("public"."formation_de_module"("module_id"))
END);



CREATE POLICY "quiz_write" ON "public"."quiz" USING ("public"."peut_gerer"(COALESCE("formation_id", "public"."formation_de_module"("module_id")))) WITH CHECK ("public"."peut_gerer"(COALESCE("formation_id", "public"."formation_de_module"("module_id"))));



ALTER TABLE "public"."ressources" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ressources_select" ON "public"."ressources" FOR SELECT USING ("public"."peut_lire"(COALESCE(( SELECT "public"."formation_de_module"("l"."module_id") AS "formation_de_module"
   FROM "public"."lecons" "l"
  WHERE ("l"."id" = "ressources"."lecon_id")), ( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "ressources"."exercice_id")))));



CREATE POLICY "ressources_write" ON "public"."ressources" USING ("public"."peut_gerer"(COALESCE(( SELECT "public"."formation_de_module"("l"."module_id") AS "formation_de_module"
   FROM "public"."lecons" "l"
  WHERE ("l"."id" = "ressources"."lecon_id")), ( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "ressources"."exercice_id"))))) WITH CHECK ("public"."peut_gerer"(COALESCE(( SELECT "public"."formation_de_module"("l"."module_id") AS "formation_de_module"
   FROM "public"."lecons" "l"
  WHERE ("l"."id" = "ressources"."lecon_id")), ( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "ressources"."exercice_id")))));



ALTER TABLE "public"."soumissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "soumissions_insert" ON "public"."soumissions" FOR INSERT TO "authenticated" WITH CHECK ((("apprenant_id" = "auth"."uid"()) AND ("note" IS NULL) AND ("corrige_at" IS NULL) AND "public"."est_inscrit"(( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "soumissions"."exercice_id")))));



CREATE POLICY "soumissions_select" ON "public"."soumissions" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"(( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "soumissions"."exercice_id")))));



CREATE POLICY "soumissions_update_apprenant" ON "public"."soumissions" FOR UPDATE TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) AND ("corrige_at" IS NULL))) WITH CHECK ((("apprenant_id" = "auth"."uid"()) AND ("note" IS NULL) AND ("corrige_at" IS NULL)));



CREATE POLICY "soumissions_update_correction" ON "public"."soumissions" FOR UPDATE TO "authenticated" USING ("public"."peut_gerer"(( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "soumissions"."exercice_id")))) WITH CHECK ("public"."peut_gerer"(( SELECT "public"."formation_de_module"("e"."module_id") AS "formation_de_module"
   FROM "public"."exercices" "e"
  WHERE ("e"."id" = "soumissions"."exercice_id"))));



ALTER TABLE "public"."tentatives_examen" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tentatives_examen_select" ON "public"."tentatives_examen" FOR SELECT USING ((("apprenant_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."quiz" "q"
  WHERE (("q"."id" = "tentatives_examen"."quiz_id") AND "public"."peut_gerer"("q"."formation_id"))))));



ALTER TABLE "public"."tentatives_quiz" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tentatives_select" ON "public"."tentatives_quiz" FOR SELECT TO "authenticated" USING ((("apprenant_id" = "auth"."uid"()) OR "public"."peut_gerer"(( SELECT "public"."formation_de_module"("q"."module_id") AS "formation_de_module"
   FROM "public"."quiz" "q"
  WHERE ("q"."id" = "tentatives_quiz"."quiz_id")))));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."_cloturer_tentative"("p_id" "uuid", "p_reponses" "jsonb", "p_statut" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_cloturer_tentative"("p_id" "uuid", "p_reponses" "jsonb", "p_statut" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."_corriger_examen"("p_quiz" "uuid", "p_reponses" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_corriger_examen"("p_quiz" "uuid", "p_reponses" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."_expirer_tentatives"("p_user" "uuid", "p_quiz" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_expirer_tentatives"("p_user" "uuid", "p_quiz" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."_niveau_info"("p" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_niveau_info"("p" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."_niveau_info"("p" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_niveau_info"("p" bigint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."_prochaine_tentative"("p_user" "uuid", "p_quiz" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_prochaine_tentative"("p_user" "uuid", "p_quiz" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_changer_responsable"("p_formation" "uuid", "p_formateur" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_changer_responsable"("p_formation" "uuid", "p_formateur" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_changer_responsable"("p_formation" "uuid", "p_formateur" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_lister_formations"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_lister_formations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_lister_formations"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_lister_utilisateurs"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_lister_utilisateurs"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_lister_utilisateurs"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_lister_utilisateurs"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_set_role"("p_user" "uuid", "p_role" "public"."user_role") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_role"("p_user" "uuid", "p_role" "public"."user_role") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_role"("p_user" "uuid", "p_role" "public"."user_role") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_statistiques"("p_jours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_statistiques"("p_jours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_statistiques"("p_jours" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."classement"("p_limite" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."classement"("p_limite" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."classement"("p_limite" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."definir_classement_visible"("p_visible" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."definir_classement_visible"("p_visible" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."definir_classement_visible"("p_visible" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."definir_mon_avatar"("p_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."definir_mon_avatar"("p_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."definir_mon_avatar"("p_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."demander_inscription"("p_formation" "uuid", "p_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."demarrer_examen"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."demarrer_examen"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."demarrer_examen"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."enregistrer_examen"("p_formation" "uuid", "p_titre" "text", "p_note_min" integer, "p_duree_min" integer, "p_max_tentatives" integer, "p_delai_reprise_h" integer, "p_publie" boolean, "p_questions" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."enregistrer_examen"("p_formation" "uuid", "p_titre" "text", "p_note_min" integer, "p_duree_min" integer, "p_max_tentatives" integer, "p_delai_reprise_h" integer, "p_publie" boolean, "p_questions" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."enregistrer_examen"("p_formation" "uuid", "p_titre" "text", "p_note_min" integer, "p_duree_min" integer, "p_max_tentatives" integer, "p_delai_reprise_h" integer, "p_publie" boolean, "p_questions" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."enregistrer_quiz"("p_module" "uuid", "p_quiz" "uuid", "p_titre" "text", "p_note_min" integer, "p_questions" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."enregistrer_reponses_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."enregistrer_reponses_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."enregistrer_reponses_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."envoyer_push"() TO "anon";
GRANT ALL ON FUNCTION "public"."envoyer_push"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."envoyer_push"() TO "service_role";



GRANT ALL ON FUNCTION "public"."est_inscrit"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."est_inscrit"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."est_inscrit"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."est_proprietaire"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."est_proprietaire"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."est_proprietaire"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."formation_de_module"("p_module" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."formation_de_module"("p_module" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."formation_de_module"("p_module" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."infos_examen"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."infos_examen"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."infos_examen"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_formateur"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_formateur"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_formateur"() TO "service_role";



GRANT ALL ON FUNCTION "public"."lire_examen_edition"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."lire_examen_edition"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lire_examen_edition"("p_formation" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mes_points"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mes_points"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mes_points"() TO "service_role";



GRANT ALL ON FUNCTION "public"."modifier_mon_profil"("p_nom" "text", "p_prenom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."modifier_mon_profil"("p_nom" "text", "p_prenom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."modifier_mon_profil"("p_nom" "text", "p_prenom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."notifier_correction"() TO "anon";
GRANT ALL ON FUNCTION "public"."notifier_correction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notifier_correction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."peut_gerer"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."peut_gerer"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."peut_gerer"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."peut_lire"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."peut_lire"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."peut_lire"("p_formation" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."proteger_role_formateur"() TO "anon";
GRANT ALL ON FUNCTION "public"."proteger_role_formateur"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proteger_role_formateur"() TO "service_role";



GRANT ALL ON FUNCTION "public"."publier_annonce"("p_formation" "uuid", "p_titre" "text", "p_corps" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."publier_annonce"("p_formation" "uuid", "p_titre" "text", "p_corps" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."publier_annonce"("p_formation" "uuid", "p_titre" "text", "p_corps" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_device_token"("p_token" "text", "p_plateforme" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."reserver_aux_apprenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."reserver_aux_apprenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reserver_aux_apprenants"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."soumettre_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."soumettre_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."soumettre_examen"("p_tentative" "uuid", "p_reponses" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."soumettre_quiz"("p_quiz_id" "uuid", "p_reponses" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."supprimer_examen"("p_formation" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."supprimer_examen"("p_formation" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."supprimer_examen"("p_formation" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."traiter_demande"("p_demande" "uuid", "p_accepter" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."verifier_responsable"() TO "anon";
GRANT ALL ON FUNCTION "public"."verifier_responsable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."verifier_responsable"() TO "service_role";



GRANT ALL ON TABLE "public"."annonces" TO "anon";
GRANT ALL ON TABLE "public"."annonces" TO "authenticated";
GRANT ALL ON TABLE "public"."annonces" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."certificats" TO "anon";
GRANT ALL ON TABLE "public"."certificats" TO "authenticated";
GRANT ALL ON TABLE "public"."certificats" TO "service_role";



GRANT ALL ON TABLE "public"."choix" TO "anon";
GRANT ALL ON TABLE "public"."choix" TO "authenticated";
GRANT ALL ON TABLE "public"."choix" TO "service_role";



GRANT ALL ON TABLE "public"."choix_corrects" TO "anon";
GRANT ALL ON TABLE "public"."choix_corrects" TO "authenticated";
GRANT ALL ON TABLE "public"."choix_corrects" TO "service_role";



GRANT ALL ON TABLE "public"."demandes_inscription" TO "anon";
GRANT ALL ON TABLE "public"."demandes_inscription" TO "authenticated";
GRANT ALL ON TABLE "public"."demandes_inscription" TO "service_role";



GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."exercices" TO "anon";
GRANT ALL ON TABLE "public"."exercices" TO "authenticated";
GRANT ALL ON TABLE "public"."exercices" TO "service_role";



GRANT ALL ON TABLE "public"."formations" TO "anon";
GRANT ALL ON TABLE "public"."formations" TO "authenticated";
GRANT ALL ON TABLE "public"."formations" TO "service_role";



GRANT ALL ON TABLE "public"."inscriptions" TO "anon";
GRANT ALL ON TABLE "public"."inscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."inscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."lecons" TO "anon";
GRANT ALL ON TABLE "public"."lecons" TO "authenticated";
GRANT ALL ON TABLE "public"."lecons" TO "service_role";



GRANT ALL ON TABLE "public"."modules" TO "anon";
GRANT ALL ON TABLE "public"."modules" TO "authenticated";
GRANT ALL ON TABLE "public"."modules" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT UPDATE("nom") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("prenom") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("avatar_url") ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."progression_lecons" TO "anon";
GRANT ALL ON TABLE "public"."progression_lecons" TO "authenticated";
GRANT ALL ON TABLE "public"."progression_lecons" TO "service_role";



GRANT ALL ON TABLE "public"."progression_formation" TO "anon";
GRANT ALL ON TABLE "public"."progression_formation" TO "authenticated";
GRANT ALL ON TABLE "public"."progression_formation" TO "service_role";



GRANT ALL ON TABLE "public"."questions" TO "anon";
GRANT ALL ON TABLE "public"."questions" TO "authenticated";
GRANT ALL ON TABLE "public"."questions" TO "service_role";



GRANT ALL ON TABLE "public"."quiz" TO "anon";
GRANT ALL ON TABLE "public"."quiz" TO "authenticated";
GRANT ALL ON TABLE "public"."quiz" TO "service_role";



GRANT ALL ON TABLE "public"."ressources" TO "anon";
GRANT ALL ON TABLE "public"."ressources" TO "authenticated";
GRANT ALL ON TABLE "public"."ressources" TO "service_role";



GRANT ALL ON TABLE "public"."soumissions" TO "anon";
GRANT ALL ON TABLE "public"."soumissions" TO "authenticated";
GRANT ALL ON TABLE "public"."soumissions" TO "service_role";



GRANT ALL ON TABLE "public"."tentatives_examen" TO "anon";
GRANT ALL ON TABLE "public"."tentatives_examen" TO "authenticated";
GRANT ALL ON TABLE "public"."tentatives_examen" TO "service_role";



GRANT ALL ON TABLE "public"."tentatives_quiz" TO "anon";
GRANT ALL ON TABLE "public"."tentatives_quiz" TO "authenticated";
GRANT ALL ON TABLE "public"."tentatives_quiz" TO "service_role";



GRANT ALL ON TABLE "public"."v_points" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







