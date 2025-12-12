create view idgen as
select lower(hex(randomblob(8))) as id;

create table hlc_seq (id integer primary key);

create table records (
  sub text not null,
  id text not null,
  hlc text not null,
  payload text not null,
  synced_at real,
  primary key (sub, id)
);

create table settings (
  key text primary key,
  value text
);
