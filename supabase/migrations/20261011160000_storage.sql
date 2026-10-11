-- Buckets (privés)
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('documents',   'documents',   false, 524288000),  -- 500 Mo
  ('rendus',      'rendus',      false, 20971520),   -- 20 Mo
  ('certificats', 'certificats', false, 20971520)    -- 20 Mo
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit;

-- On repart d'une base propre pour ces règles
drop policy if exists certificats_read on storage.objects;
drop policy if exists documents_read   on storage.objects;
drop policy if exists documents_write  on storage.objects;
drop policy if exists rendus_insert    on storage.objects;
drop policy if exists rendus_select    on storage.objects;
drop policy if exists rendus_delete    on storage.objects;

-- certificats : chacun lit les siens (dossier = id de l'utilisateur)
create policy certificats_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'certificats'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- documents : lecture si on peut lire la formation, écriture si on la gère
create policy documents_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and peut_lire(((storage.foldername(name))[1])::uuid)
  );

create policy documents_write on storage.objects
  for all to authenticated
  using (
    bucket_id = 'documents'
    and peut_gerer(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'documents'
    and peut_gerer(((storage.foldername(name))[1])::uuid)
  );

-- rendus : chemin <exercice_id>/<apprenant_id>/<fichier>
create policy rendus_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'rendus'
    and (storage.foldername(name))[2] = auth.uid()::text
    and est_inscrit(formation_de_module((
      select e.module_id from exercices e
      where e.id = ((storage.foldername(objects.name))[1])::uuid
    )))
    and not exists (
      select 1 from soumissions s
      where s.exercice_id = ((storage.foldername(objects.name))[1])::uuid
        and s.apprenant_id = auth.uid()
        and s.corrige_at is not null
    )
  );

create policy rendus_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'rendus'
    and (
      (storage.foldername(name))[2] = auth.uid()::text
      or peut_gerer(formation_de_module((
        select e.module_id from exercices e
        where e.id = ((storage.foldername(objects.name))[1])::uuid
      )))
    )
  );

create policy rendus_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'rendus'
    and (storage.foldername(name))[2] = auth.uid()::text
    and not exists (
      select 1 from soumissions s
      where s.exercice_id = ((storage.foldername(objects.name))[1])::uuid
        and s.apprenant_id = auth.uid()
        and s.corrige_at is not null
    )
  );