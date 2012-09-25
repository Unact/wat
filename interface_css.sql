define 'service', 'css';

define 'procedure', 'interface.css';

alter function interface.css (in @type varchar(128))
returns text
begin
return 
'      
 body, input {font-family:  Helvetica, Lucidia Console, Arial; font-size: 12px;text-align: center;}
 body { background-image: url(/gallery_image/5); background-repeat: repeat; margin: 0px 0px auto; }

 input {margin: 0px;}
 #menu {margin: 0px auto; }

 #main {padding: 0px;}

 #message,.menupad, #menu {padding: 6px;}
      
 .menupad { color: blue; text-decoration: underline; font-size: 1em; font-weight: bold;}


 #message {margin: 0px; border-bottom: solid 3px #C0C0C0;}

 td, #message, .menupad:hover {background-color: #EEEEEE;}

 tr.totals td, #menu, table {background-color: #C0C0C0;}


 .rowgroup2 td span{font-size: 1em; display: block; font-weight: bold;}
 .rowgroup1 td span{font-size: 1.2em; margin: 1em auto; display: block; font-weight: bold;}

 td.editable, .boolean, th {text-align: center;}
 
 tr.totals td {font-weight: bold;}

 tr.error td, tr.error td *, .error {color: red;}

 .number {text-align: right;}

 table {border-spacing: 2px; margin: 1em auto; text-align: left; }

 .rowgroup2 td span {margin: 1em auto 0.2em;}
      
 td input.number {margin: 0px -6px 0px -6px; display:block; width: 100%; padding: 2px auto;}

 td, table {padding: 3px;}

 td.editable {padding: 1px 1px 1px 7px;}

 #login, #login input[type=text], #login input[type=password] {font-size: 15px; }
 #login {text-align: left; margin:7em auto; border: 4px solid silver;
         width: 30em; padding: 2em; background-color: #EEEEEE;
 }

'
end;


alter  service "css" type 'raw' authorization off user dba 
url elements
as call interface.return_as_text(interface.css(:url1));