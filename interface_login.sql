define 'procedure', 'interface.auth';


alter function interface.auth (@uid varchar(64) default null, @pwd varchar(64) default null)
returns xml
begin
 declare @result xml;

 begin

  set @result=

'<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <meta http-equiv="Content-Type" content="text/html; charset=windows-1251" />
      <link rel="shortcut icon" href="/gallery_image/1" />
      <link rel="stylesheet" type="text/css" href="/css/main" />
    </head>
    <body>
     <div id="login">
      <p>Для авторизации в системе введите имя и пароль, такие же как при запуске компьютера (ctrl+alt+del)</p>'
    +if @uid is not null then '
      <p class="error">Неправильное имя или пароль</p>' else '' endif+'
      <form name="login" method="post" action="/xml">
        <p><label>Имя:</label> <input type="text" name="username" value ="'+isnull(@uid,'')+'"/></p>
        <p><label>Пароль:</label> <input type="password" name="password" value="'+isnull(@pwd,'')+'"/></p>
        <input type="submit" value="OK" />
      </form>
     </div>
    </body>
</html>'


 exception when others then
    set @result=
          xmlelement('exception',
                     xmlconcat(xmlelement('ErrorText',errormsg())
                              ,xmlelement('SQLSTATE',SQLSTATE)
                     )
          );
 end;

 return @result;

end;


