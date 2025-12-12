create view idgen as
select lower(hex(randomblob(8))) as id;

create table records (
  sub text not null,
  id text not null,
  hlc text not null,
  payload text not null,
  primary key (sub, id)
);

create index idx_records_sub on records(sub);
