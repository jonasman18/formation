SET local check_function_bodies = off;

CREATE EXTENSION "pg_net" SCHEMA "extensions";

CREATE TABLE "public"."annonces" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "formation_id" uuid                     NOT NULL,
  "auteur_id"    uuid                     NOT NULL,
  "titre"        text                     NOT NULL,
  "contenu"      text,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "annonces_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."annonces"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."categories" (
  "id"  uuid NOT NULL DEFAULT gen_random_uuid(),
  "nom" text NOT NULL,
  CONSTRAINT "categories_nom_key" UNIQUE (nom),
  CONSTRAINT "categories_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."categories"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."certificats" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "apprenant_id" uuid                     NOT NULL,
  "formation_id" uuid                     NOT NULL,
  "code"         text                     NOT NULL DEFAULT encode(extensions.gen_random_bytes(6), 'hex'::text),
  "fichier_path" text,
  "delivre_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "certificats_apprenant_id_formation_id_key" UNIQUE (apprenant_id, formation_id),
  CONSTRAINT "certificats_code_key" UNIQUE (code),
  CONSTRAINT "certificats_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."certificats"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."choix_corrects" (
  "choix_id" uuid NOT NULL,
  CONSTRAINT "choix_corrects_pkey" PRIMARY KEY (choix_id)
);

ALTER TABLE "public"."choix_corrects"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."choix" (
  "id"          uuid NOT NULL DEFAULT gen_random_uuid(),
  "question_id" uuid NOT NULL,
  "texte"       text NOT NULL,
  CONSTRAINT "choix_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."choix"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."demandes_inscription" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "apprenant_id" uuid                     NOT NULL,
  "formation_id" uuid                     NOT NULL,
  "statut"       text                     NOT NULL DEFAULT 'en_attente'::text,
  "message"      text,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "traite_at"    timestamp with time zone,
  "traite_par"   uuid,
  CONSTRAINT "demandes_inscription_apprenant_id_formation_id_key" UNIQUE (apprenant_id, formation_id),
  CONSTRAINT "demandes_inscription_pkey" PRIMARY KEY (id),
  CONSTRAINT "demandes_inscription_statut_check" CHECK ((statut = ANY (ARRAY['en_attente'::text, 'acceptee'::text, 'refusee'::text])))
);

ALTER TABLE "public"."demandes_inscription"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."device_tokens" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "token"      text                     NOT NULL,
  "plateforme" text,
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "device_tokens_pkey" PRIMARY KEY (id),
  CONSTRAINT "device_tokens_plateforme_check" CHECK ((plateforme = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text]))),
  CONSTRAINT "device_tokens_token_key" UNIQUE (token)
);

ALTER TABLE "public"."device_tokens"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."exercices" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "module_id"   uuid                     NOT NULL,
  "titre"       text                     NOT NULL,
  "consigne"    text,
  "date_limite" timestamp with time zone,
  CONSTRAINT "exercices_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."exercices"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."formations" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "titre"        text                     NOT NULL,
  "description"  text,
  "image_url"    text,
  "categorie_id" uuid,
  "formateur_id" uuid                     NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "acces"        text                     NOT NULL DEFAULT 'libre'::text,
  CONSTRAINT "formations_acces_check" CHECK ((acces = ANY (ARRAY['libre'::text, 'sur_demande'::text]))),
  CONSTRAINT "formations_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."formations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."inscriptions" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "apprenant_id" uuid                     NOT NULL,
  "formation_id" uuid                     NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "inscriptions_apprenant_id_formation_id_key" UNIQUE (apprenant_id, formation_id),
  CONSTRAINT "inscriptions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."inscriptions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."lecons" (
  "id"        uuid    NOT NULL DEFAULT gen_random_uuid(),
  "module_id" uuid    NOT NULL,
  "titre"     text    NOT NULL,
  "url"       text,
  "contenu"   text,
  "duree_sec" integer,
  "ordre"     integer NOT NULL DEFAULT 0,
  CONSTRAINT "lecons_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."lecons"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modules" (
  "id"           uuid    NOT NULL DEFAULT gen_random_uuid(),
  "formation_id" uuid    NOT NULL,
  "titre"        text    NOT NULL,
  "ordre"        integer NOT NULL DEFAULT 0,
  CONSTRAINT "modules_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."modules"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."notifications" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "titre"      text                     NOT NULL,
  "corps"      text,
  "lue"        boolean                  NOT NULL DEFAULT false,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "notifications_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."notifications"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."profiles" (
  "id"         uuid                     NOT NULL,
  "nom"        text,
  "prenom"     text,
  "avatar_url" text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."progression_lecons" (
  "apprenant_id" uuid                     NOT NULL,
  "lecon_id"     uuid                     NOT NULL,
  "terminee_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "progression_lecons_pkey" PRIMARY KEY (apprenant_id, lecon_id)
);

ALTER TABLE "public"."progression_lecons"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."questions" (
  "id"      uuid    NOT NULL DEFAULT gen_random_uuid(),
  "quiz_id" uuid    NOT NULL,
  "enonce"  text    NOT NULL,
  "ordre"   integer NOT NULL DEFAULT 0,
  CONSTRAINT "questions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."questions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."quiz" (
  "id"        uuid    NOT NULL DEFAULT gen_random_uuid(),
  "module_id" uuid    NOT NULL,
  "titre"     text    NOT NULL,
  "note_min"  integer NOT NULL DEFAULT 50,
  CONSTRAINT "quiz_note_min_check" CHECK (((note_min >= 0) AND (note_min <= 100))),
  CONSTRAINT "quiz_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."quiz"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."ressources" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "lecon_id"    uuid,
  "type"        text                     NOT NULL,
  "titre"       text,
  "url"         text                     NOT NULL,
  "ordre"       integer                  NOT NULL DEFAULT 1,
  "created_at"  timestamp with time zone DEFAULT now(),
  "exercice_id" uuid,
  CONSTRAINT "ressources_parent_chk" CHECK (((((lecon_id IS NOT NULL))::integer + ((exercice_id IS NOT NULL))::integer) = 1)),
  CONSTRAINT "ressources_pkey" PRIMARY KEY (id),
  CONSTRAINT "ressources_type_check" CHECK ((type = ANY (ARRAY['pdf'::text, 'video'::text])))
);

ALTER TABLE "public"."ressources"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."soumissions" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "exercice_id"  uuid                     NOT NULL,
  "apprenant_id" uuid                     NOT NULL,
  "contenu"      text,
  "fichier_path" text,
  "note"         numeric(5,2),
  "commentaire"  text,
  "soumis_at"    timestamp with time zone NOT NULL DEFAULT now(),
  "corrige_at"   timestamp with time zone,
  CONSTRAINT "soumissions_exercice_id_apprenant_id_key" UNIQUE (exercice_id, apprenant_id),
  CONSTRAINT "soumissions_note_check" CHECK (((note >= (0)::numeric) AND (note <= (20)::numeric))),
  CONSTRAINT "soumissions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."soumissions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."tentatives_quiz" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "quiz_id"      uuid                     NOT NULL,
  "apprenant_id" uuid                     NOT NULL,
  "score"        integer                  NOT NULL,
  "reussi"       boolean                  NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "tentatives_quiz_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."tentatives_quiz"
  ENABLE ROW LEVEL SECURITY;

CREATE TYPE "public"."statut_formation" AS ENUM (
  'brouillon',
  'publie',
  'archive'
);

ALTER TABLE "public"."formations"
  ADD COLUMN "statut" public.statut_formation NOT NULL DEFAULT 'brouillon'::public.statut_formation;

CREATE TYPE "public"."type_lecon" AS ENUM (
  'video',
  'pdf',
  'texte'
);

ALTER TABLE "public"."lecons"
  ADD COLUMN "type" public.type_lecon NOT NULL;

CREATE TYPE "public"."user_role" AS ENUM (
  'apprenant',
  'formateur',
  'admin'
);

ALTER TABLE "public"."profiles"
  ADD COLUMN "role" public.user_role NOT NULL DEFAULT 'apprenant'::public.user_role;

CREATE OR REPLACE FUNCTION public.admin_lister_utilisateurs()
  RETURNS TABLE (
    id         uuid,
    nom        text,
    prenom     text,
    email      text,
    role       public.user_role,
    created_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not is_admin() then
    raise exception 'Accès refusé';
  end if;
  return query
    select p.id, p.nom, p.prenom, u.email::text, p.role, p.created_at
    from profiles p
    join auth.users u on u.id = p.id
    order by p.created_at desc;
end $function$;

CREATE OR REPLACE FUNCTION public.admin_set_role (
  p_user uuid,
  p_role public.user_role
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not is_admin() then raise exception 'Accès refusé'; end if;
  update profiles set role = p_role where id = p_user;
end $function$;

CREATE OR REPLACE FUNCTION public.demander_inscription (
  p_formation uuid,
  p_message   text DEFAULT NULL::text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.enregistrer_quiz (
  p_module    uuid,
  p_quiz      uuid,
  p_titre     text,
  p_note_min  integer,
  p_questions jsonb
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.envoyer_push()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.est_inscrit (
  p_formation uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from inscriptions
                 where formation_id = p_formation and apprenant_id = auth.uid());
$function$;

CREATE OR REPLACE FUNCTION public.est_proprietaire (
  p_formation uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from formations
                 where id = p_formation and formateur_id = auth.uid());
$function$;

CREATE OR REPLACE FUNCTION public.formation_de_module (
  p_module uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select formation_id from modules where id = p_module;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into profiles (id, nom, prenom)
  values (new.id,
          new.raw_user_meta_data->>'nom',
          new.raw_user_meta_data->>'prenom');
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$function$;

CREATE OR REPLACE FUNCTION public.is_formateur()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from profiles where id = auth.uid() and role in ('formateur','admin'));
$function$;

CREATE OR REPLACE FUNCTION public.notifier_correction()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.peut_gerer (
  p_formation uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select is_admin() or est_proprietaire(p_formation);
$function$;

CREATE OR REPLACE FUNCTION public.peut_lire (
  p_formation uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select peut_gerer(p_formation) or est_inscrit(p_formation);
$function$;

CREATE OR REPLACE FUNCTION public.register_device_token (
  p_token      text,
  p_plateforme text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.soumettre_quiz (
  p_quiz_id  uuid,
  p_reponses jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.traiter_demande (
  p_demande  uuid,
  p_accepter boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
end $function$;

ALTER TABLE "public"."choix_corrects"
  ADD CONSTRAINT "choix_corrects_choix_id_fkey" FOREIGN KEY (choix_id) REFERENCES public.choix(id) ON DELETE CASCADE;

ALTER TABLE "public"."formations"
  ADD CONSTRAINT "formations_categorie_id_fkey" FOREIGN KEY (categorie_id) REFERENCES public.categories(id) ON DELETE SET NULL;

ALTER TABLE "public"."annonces"
  ADD CONSTRAINT "annonces_formation_id_fkey" FOREIGN KEY (formation_id) REFERENCES public.formations(id) ON DELETE CASCADE;

ALTER TABLE "public"."certificats"
  ADD CONSTRAINT "certificats_formation_id_fkey" FOREIGN KEY (formation_id) REFERENCES public.formations(id) ON DELETE CASCADE;

ALTER TABLE "public"."demandes_inscription"
  ADD CONSTRAINT "demandes_inscription_formation_id_fkey" FOREIGN KEY (formation_id) REFERENCES public.formations(id) ON DELETE CASCADE;

ALTER TABLE "public"."inscriptions"
  ADD CONSTRAINT "inscriptions_formation_id_fkey" FOREIGN KEY (formation_id) REFERENCES public.formations(id) ON DELETE CASCADE;

ALTER TABLE "public"."modules"
  ADD CONSTRAINT "modules_formation_id_fkey" FOREIGN KEY (formation_id) REFERENCES public.formations(id) ON DELETE CASCADE;

ALTER TABLE "public"."exercices"
  ADD CONSTRAINT "exercices_module_id_fkey" FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;

ALTER TABLE "public"."lecons"
  ADD CONSTRAINT "lecons_module_id_fkey" FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."annonces"
  ADD CONSTRAINT "annonces_auteur_id_fkey" FOREIGN KEY (auteur_id) REFERENCES public.profiles(id);

ALTER TABLE "public"."certificats"
  ADD CONSTRAINT "certificats_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."demandes_inscription"
  ADD CONSTRAINT "demandes_inscription_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."demandes_inscription"
  ADD CONSTRAINT "demandes_inscription_traite_par_fkey" FOREIGN KEY (traite_par) REFERENCES public.profiles(id);

ALTER TABLE "public"."device_tokens"
  ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."formations"
  ADD CONSTRAINT "formations_formateur_id_fkey" FOREIGN KEY (formateur_id) REFERENCES public.profiles(id);

ALTER TABLE "public"."inscriptions"
  ADD CONSTRAINT "inscriptions_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."notifications"
  ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."progression_lecons"
  ADD CONSTRAINT "progression_lecons_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."progression_lecons"
  ADD CONSTRAINT "progression_lecons_lecon_id_fkey" FOREIGN KEY (lecon_id) REFERENCES public.lecons(id) ON DELETE CASCADE;

ALTER TABLE "public"."choix"
  ADD CONSTRAINT "choix_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz"
  ADD CONSTRAINT "quiz_module_id_fkey" FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;

ALTER TABLE "public"."questions"
  ADD CONSTRAINT "questions_quiz_id_fkey" FOREIGN KEY (quiz_id) REFERENCES public.quiz(id) ON DELETE CASCADE;

ALTER TABLE "public"."ressources"
  ADD CONSTRAINT "ressources_exercice_id_fkey" FOREIGN KEY (exercice_id) REFERENCES public.exercices(id) ON DELETE CASCADE;

ALTER TABLE "public"."ressources"
  ADD CONSTRAINT "ressources_lecon_id_fkey" FOREIGN KEY (lecon_id) REFERENCES public.lecons(id) ON DELETE CASCADE;

ALTER TABLE "public"."soumissions"
  ADD CONSTRAINT "soumissions_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."soumissions"
  ADD CONSTRAINT "soumissions_exercice_id_fkey" FOREIGN KEY (exercice_id) REFERENCES public.exercices(id) ON DELETE CASCADE;

ALTER TABLE "public"."tentatives_quiz"
  ADD CONSTRAINT "tentatives_quiz_apprenant_id_fkey" FOREIGN KEY (apprenant_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."tentatives_quiz"
  ADD CONSTRAINT "tentatives_quiz_quiz_id_fkey" FOREIGN KEY (quiz_id) REFERENCES public.quiz(id) ON DELETE CASCADE;

CREATE VIEW "public"."progression_formation" WITH (security_invoker=true) AS  SELECT i.apprenant_id,
    i.formation_id,
    count(l.id) AS total_lecons,
    count(p.lecon_id) AS lecons_terminees,
        CASE
            WHEN (count(l.id) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (count(p.lecon_id))::numeric) / (count(l.id))::numeric))
        END AS pourcentage
   FROM (((public.inscriptions i
     JOIN public.modules m ON ((m.formation_id = i.formation_id)))
     JOIN public.lecons l ON ((l.module_id = m.id)))
     LEFT JOIN public.progression_lecons p ON (((p.lecon_id = l.id) AND (p.apprenant_id = i.apprenant_id))))
  GROUP BY i.apprenant_id, i.formation_id;

CREATE INDEX demandes_formation_idx ON public.demandes_inscription USING btree (formation_id, statut);

CREATE INDEX formations_categorie_id_idx ON public.formations USING btree (categorie_id);

CREATE INDEX formations_formateur_id_idx ON public.formations USING btree (formateur_id);

CREATE INDEX lecons_module_id_idx ON public.lecons USING btree (module_id);

CREATE INDEX modules_formation_id_idx ON public.modules USING btree (formation_id);

CREATE INDEX notifications_user_id_created_at_idx ON public.notifications USING btree (user_id, created_at DESC);

CREATE INDEX ressources_lecon_id_idx ON public.ressources USING btree (lecon_id);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER notifications_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.envoyer_push();

CREATE TRIGGER soumissions_notifier
  AFTER UPDATE ON public.soumissions
  FOR EACH ROW
  EXECUTE FUNCTION public.notifier_correction();

CREATE POLICY "annonces_select" ON "public"."annonces"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(formation_id));

CREATE POLICY "annonces_write" ON "public"."annonces"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(formation_id))
  WITH CHECK ((public.peut_gerer(formation_id) AND (auteur_id = auth.uid())));

CREATE POLICY "categories_admin" ON "public"."categories"
  FOR ALL
  TO "authenticated"
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "categories_select" ON "public"."categories"
  FOR SELECT
  TO "authenticated"
  USING (true);

CREATE POLICY "certificats_select" ON "public"."certificats"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(formation_id)));

CREATE POLICY "choix_select" ON "public"."choix"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(( SELECT public.formation_de_module(qz.module_id) AS formation_de_module
   FROM (public.questions qu
     JOIN public.quiz qz ON ((qz.id = qu.quiz_id)))
  WHERE (qu.id = choix.question_id))));

CREATE POLICY "choix_write" ON "public"."choix"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(( SELECT public.formation_de_module(qz.module_id) AS formation_de_module
   FROM (public.questions qu
     JOIN public.quiz qz ON ((qz.id = qu.quiz_id)))
  WHERE (qu.id = choix.question_id))))
  WITH CHECK (public.peut_gerer(( SELECT public.formation_de_module(qz.module_id) AS formation_de_module
   FROM (public.questions qu
     JOIN public.quiz qz ON ((qz.id = qu.quiz_id)))
  WHERE (qu.id = choix.question_id))));

CREATE POLICY "choix_corrects_staff" ON "public"."choix_corrects"
  FOR ALL
  TO "authenticated"
  USING (public.is_formateur())
  WITH CHECK (public.is_formateur());

CREATE POLICY "demandes_delete" ON "public"."demandes_inscription"
  FOR DELETE
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) AND (statut = 'en_attente'::text)));

CREATE POLICY "demandes_select" ON "public"."demandes_inscription"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(formation_id)));

CREATE POLICY "device_tokens_own" ON "public"."device_tokens"
  FOR ALL
  TO "authenticated"
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "exercices_select" ON "public"."exercices"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(public.formation_de_module(module_id)));

CREATE POLICY "exercices_write" ON "public"."exercices"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(public.formation_de_module(module_id)))
  WITH CHECK (public.peut_gerer(public.formation_de_module(module_id)));

CREATE POLICY "formations_delete" ON "public"."formations"
  FOR DELETE
  TO "authenticated"
  USING (public.peut_gerer(id));

CREATE POLICY "formations_insert" ON "public"."formations"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((public.is_formateur() AND ((formateur_id = auth.uid()) OR public.is_admin())));

CREATE POLICY "formations_select" ON "public"."formations"
  FOR SELECT
  TO "authenticated"
  USING (((statut = 'publie'::public.statut_formation) OR public.peut_gerer(id)));

CREATE POLICY "formations_update" ON "public"."formations"
  FOR UPDATE
  TO "authenticated"
  USING (public.peut_gerer(id))
  WITH CHECK (public.peut_gerer(id));

CREATE POLICY "inscriptions_delete" ON "public"."inscriptions"
  FOR DELETE
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "inscriptions_insert" ON "public"."inscriptions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((apprenant_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.formations f
  WHERE ((f.id = inscriptions.formation_id) AND (f.statut = 'publie'::public.statut_formation) AND (f.acces = 'libre'::text))))));

CREATE POLICY "inscriptions_select" ON "public"."inscriptions"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(formation_id)));

CREATE POLICY "lecons_select" ON "public"."lecons"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(public.formation_de_module(module_id)));

CREATE POLICY "lecons_write" ON "public"."lecons"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(public.formation_de_module(module_id)))
  WITH CHECK (public.peut_gerer(public.formation_de_module(module_id)));

CREATE POLICY "modules_select" ON "public"."modules"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(formation_id));

CREATE POLICY "modules_write" ON "public"."modules"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(formation_id))
  WITH CHECK (public.peut_gerer(formation_id));

CREATE POLICY "notifications_delete" ON "public"."notifications"
  FOR DELETE
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "notifications_select" ON "public"."notifications"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "notifications_update" ON "public"."notifications"
  FOR UPDATE
  TO "authenticated"
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "profiles_admin_all" ON "public"."profiles"
  FOR ALL
  TO "authenticated"
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "profiles_select" ON "public"."profiles"
  FOR SELECT
  TO "authenticated"
  USING (((id = auth.uid()) OR public.is_formateur()));

CREATE POLICY "profiles_update_self" ON "public"."profiles"
  FOR UPDATE
  TO "authenticated"
  USING ((id = auth.uid()))
  WITH CHECK ((id = auth.uid()));

CREATE POLICY "progression_delete" ON "public"."progression_lecons"
  FOR DELETE
  TO "authenticated"
  USING ((apprenant_id = auth.uid()));

CREATE POLICY "progression_insert" ON "public"."progression_lecons"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((apprenant_id = auth.uid()) AND public.est_inscrit(( SELECT public.formation_de_module(l.module_id) AS formation_de_module
   FROM public.lecons l
  WHERE (l.id = progression_lecons.lecon_id)))));

CREATE POLICY "progression_select" ON "public"."progression_lecons"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(( SELECT public.formation_de_module(l.module_id) AS formation_de_module
   FROM public.lecons l
  WHERE (l.id = progression_lecons.lecon_id)))));

CREATE POLICY "questions_select" ON "public"."questions"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(( SELECT public.formation_de_module(q.module_id) AS formation_de_module
   FROM public.quiz q
  WHERE (q.id = questions.quiz_id))));

CREATE POLICY "questions_write" ON "public"."questions"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(( SELECT public.formation_de_module(q.module_id) AS formation_de_module
   FROM public.quiz q
  WHERE (q.id = questions.quiz_id))))
  WITH CHECK (public.peut_gerer(( SELECT public.formation_de_module(q.module_id) AS formation_de_module
   FROM public.quiz q
  WHERE (q.id = questions.quiz_id))));

CREATE POLICY "quiz_select" ON "public"."quiz"
  FOR SELECT
  TO "authenticated"
  USING (public.peut_lire(public.formation_de_module(module_id)));

CREATE POLICY "quiz_write" ON "public"."quiz"
  FOR ALL
  TO "authenticated"
  USING (public.peut_gerer(public.formation_de_module(module_id)))
  WITH CHECK (public.peut_gerer(public.formation_de_module(module_id)));

CREATE POLICY "ressources_select" ON "public"."ressources"
  FOR SELECT
  TO PUBLIC
  USING (public.peut_lire(COALESCE(( SELECT public.formation_de_module(l.module_id) AS formation_de_module
   FROM public.lecons l
  WHERE (l.id = ressources.lecon_id)), ( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = ressources.exercice_id)))));

CREATE POLICY "ressources_write" ON "public"."ressources"
  FOR ALL
  TO PUBLIC
  USING (public.peut_gerer(COALESCE(( SELECT public.formation_de_module(l.module_id) AS formation_de_module
   FROM public.lecons l
  WHERE (l.id = ressources.lecon_id)), ( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = ressources.exercice_id)))))
  WITH CHECK (public.peut_gerer(COALESCE(( SELECT public.formation_de_module(l.module_id) AS formation_de_module
   FROM public.lecons l
  WHERE (l.id = ressources.lecon_id)), ( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = ressources.exercice_id)))));

CREATE POLICY "soumissions_insert" ON "public"."soumissions"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK (((apprenant_id = auth.uid()) AND (note IS NULL) AND (corrige_at IS NULL) AND public.est_inscrit(( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = soumissions.exercice_id)))));

CREATE POLICY "soumissions_select" ON "public"."soumissions"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = soumissions.exercice_id)))));

CREATE POLICY "soumissions_update_apprenant" ON "public"."soumissions"
  FOR UPDATE
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) AND (corrige_at IS NULL)))
  WITH CHECK (((apprenant_id = auth.uid()) AND (note IS NULL) AND (corrige_at IS NULL)));

CREATE POLICY "soumissions_update_correction" ON "public"."soumissions"
  FOR UPDATE
  TO "authenticated"
  USING (public.peut_gerer(( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = soumissions.exercice_id))))
  WITH CHECK (public.peut_gerer(( SELECT public.formation_de_module(e.module_id) AS formation_de_module
   FROM public.exercices e
  WHERE (e.id = soumissions.exercice_id))));

CREATE POLICY "tentatives_select" ON "public"."tentatives_quiz"
  FOR SELECT
  TO "authenticated"
  USING (((apprenant_id = auth.uid()) OR public.peut_gerer(( SELECT public.formation_de_module(q.module_id) AS formation_de_module
   FROM public.quiz q
  WHERE (q.id = tentatives_quiz.quiz_id)))));

CREATE POLICY "certificats_read" ON "storage"."objects"
  FOR SELECT
  TO "authenticated"
  USING (((bucket_id = 'certificats'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

CREATE POLICY "documents_read" ON "storage"."objects"
  FOR SELECT
  TO "authenticated"
  USING (((bucket_id = 'documents'::text) AND public.peut_lire(((storage.foldername(name))[1])::uuid)));

CREATE POLICY "documents_write" ON "storage"."objects"
  FOR ALL
  TO "authenticated"
  USING (((bucket_id = 'documents'::text) AND public.peut_gerer(((storage.foldername(name))[1])::uuid)))
  WITH CHECK (((bucket_id = 'documents'::text) AND public.peut_gerer(((storage.foldername(name))[1])::uuid)));

CREATE POLICY "rendus_delete" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING (((bucket_id = 'rendus'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text) AND (NOT (EXISTS ( SELECT 1
   FROM public.soumissions s
  WHERE ((s.exercice_id = ((storage.foldername(objects.name))[1])::uuid) AND (s.apprenant_id = auth.uid()) AND (s.corrige_at IS NOT NULL)))))));

CREATE POLICY "rendus_insert" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'rendus'::text) AND ((storage.foldername(name))[2] = (auth.uid())::text) AND public.est_inscrit(public.formation_de_module(( SELECT e.module_id
   FROM public.exercices e
  WHERE (e.id = ((storage.foldername(objects.name))[1])::uuid)))) AND (NOT (EXISTS ( SELECT 1
   FROM public.soumissions s
  WHERE ((s.exercice_id = ((storage.foldername(objects.name))[1])::uuid) AND (s.apprenant_id = auth.uid()) AND (s.corrige_at IS NOT NULL)))))));

CREATE POLICY "rendus_select" ON "storage"."objects"
  FOR SELECT
  TO "authenticated"
  USING (((bucket_id = 'rendus'::text) AND (((storage.foldername(name))[2] = (auth.uid())::text) OR public.peut_gerer(public.formation_de_module(( SELECT e.module_id
   FROM public.exercices e
  WHERE (e.id = ((storage.foldername(objects.name))[1])::uuid)))))));

CREATE EVENT TRIGGER "ensure_rls"
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION "public"."rls_auto_enable"();

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."notifications";

COMMENT ON EXTENSION "pg_net" IS 'Async HTTP';

REVOKE ALL ON FUNCTION "public"."admin_lister_utilisateurs"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."admin_lister_utilisateurs"() TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."admin_lister_utilisateurs"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."admin_lister_utilisateurs"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."admin_lister_utilisateurs"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."admin_set_role"(uuid, public.user_role) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."admin_set_role"(uuid, public.user_role) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."admin_set_role"(uuid, public.user_role) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."admin_set_role"(uuid, public.user_role) TO "service_role";

REVOKE ALL ON FUNCTION "public"."demander_inscription"(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."demander_inscription"(uuid, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."demander_inscription"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."demander_inscription"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."demander_inscription"(uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."enregistrer_quiz"(uuid, uuid, text, integer, jsonb) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."enregistrer_quiz"(uuid, uuid, text, integer, jsonb) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."enregistrer_quiz"(uuid, uuid, text, integer, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."enregistrer_quiz"(uuid, uuid, text, integer, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."enregistrer_quiz"(uuid, uuid, text, integer, jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."envoyer_push"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."envoyer_push"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."envoyer_push"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."envoyer_push"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."est_inscrit"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."est_inscrit"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."est_inscrit"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."est_inscrit"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."est_proprietaire"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."est_proprietaire"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."est_proprietaire"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."est_proprietaire"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."formation_de_module"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."formation_de_module"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."formation_de_module"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."formation_de_module"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_admin"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_admin"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_admin"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_admin"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_formateur"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_formateur"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_formateur"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_formateur"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."notifier_correction"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."notifier_correction"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."notifier_correction"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."notifier_correction"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."peut_gerer"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."peut_gerer"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."peut_gerer"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."peut_gerer"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."peut_lire"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."peut_lire"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."peut_lire"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."peut_lire"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."register_device_token"(text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."register_device_token"(text, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."register_device_token"(text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."register_device_token"(text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."register_device_token"(text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."soumettre_quiz"(uuid, jsonb) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."soumettre_quiz"(uuid, jsonb) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."soumettre_quiz"(uuid, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."soumettre_quiz"(uuid, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."soumettre_quiz"(uuid, jsonb) TO "service_role";

REVOKE ALL ON FUNCTION "public"."traiter_demande"(uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."traiter_demande"(uuid, boolean) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."traiter_demande"(uuid, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."traiter_demande"(uuid, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."traiter_demande"(uuid, boolean) TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."annonces" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."annonces" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."annonces" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."annonces" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."categories" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."certificats" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."certificats" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."certificats" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."certificats" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."choix" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix_corrects" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."choix_corrects" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix_corrects" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."choix_corrects" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."demandes_inscription" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."demandes_inscription" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."demandes_inscription" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."demandes_inscription" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."device_tokens" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."device_tokens" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."device_tokens" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."device_tokens" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."exercices" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."exercices" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."exercices" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."exercices" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."formations" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."formations" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."formations" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."formations" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."inscriptions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."inscriptions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."inscriptions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."inscriptions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lecons" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."lecons" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lecons" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lecons" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modules" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."modules" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modules" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modules" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifications" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."notifications" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifications" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."notifications" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "anon";

REVOKE ALL ON TABLE "public"."profiles" FROM "authenticated";

REVOKE ALL ("avatar_url") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("avatar_url") ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ("nom") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("nom") ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ("prenom") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("prenom") ON TABLE "public"."profiles" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ON TABLE "public"."profiles" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_lecons" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."progression_lecons" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_lecons" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_lecons" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."questions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."questions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."quiz" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ressources" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."ressources" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ressources" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ressources" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."soumissions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."soumissions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."soumissions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."soumissions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tentatives_quiz" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."tentatives_quiz" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tentatives_quiz" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tentatives_quiz" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_formation" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."progression_formation" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_formation" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."progression_formation" TO "service_role";

