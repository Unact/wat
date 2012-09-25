concept _session;


method '_session.register',interface;
method '_session.setcookie', _session;


if not exists (select * from systable
                where table_name='_session' and creator=user_id('_session'))
then
  create table _session._session (
     id uniqueidentifier,
     username varchar(128) not null,
     useragent long varchar,
     primary key (id)
  );

  create view interface._session
  as select * from _session._session;

  grant select, update on interface._session to interface;
end if;




alter procedure _session.setCookie (
			name	varchar(250),
			value	long varchar,
			max_age	integer,
			path	varchar(250) default '/' )
begin
  call dbo.sa_set_http_header( 'Set-Cookie',
     name + '=' + value
       + ';'+
     ' max-age=' + string( max_age )
       + ';'+
     ' path=' + path
       + ';' +
--     ' expires=' + '8h'
     ''
  );
end;


alter function _session.register ()
returns uniqueidentifier
begin

 if nullif(connection_property('sessionid'),'') is null then

   create variable _session_username varchar(128);
   create variable _session_id uniqueidentifier;
   create variable _session_device varchar(32);

   set _session_id       = newid();
   set _session_username = http_variable('username');
   set _session_device   = if http_header('user-agent') like '%iPod;%' then
                             'ipod'
                           else 'pc'
                           endif
   ;

   insert into _session (id, username, useragent)
     values (_session_id, _session_username, http_header('user-agent') )
   ;
   
   call sa_set_http_option('sessionid', _session_id );

 end if;

 call setCookie ('xml_sessionid', _session_id, 4200, '/xml');

 return _session_id

end;

