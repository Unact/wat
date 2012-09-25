define 'service', 'xsl';

define 'procedure', 'interface.xsl';
define 'procedure', 'interface.xsl_makeid';
define 'procedure', 'interface.xsl_post';
define 'procedure', 'interface.xsl_format';




alter  service "xsl" type 'raw' authorization off user dba 
url elements
as call interface.return_as_xml(
  case isnull(http_variable('url1'),'')
    when '' then interface.xsl ()
    when 'makeid' then interface.xsl_makeid (isnull(http_variable('url2'),'0'))
    when 'post' then interface.xsl_post ()
    when 'format' then interface.xsl_format ()
  end
);


alter function interface.xsl_format ()
returns xml
begin

return 
'<?xml version="1.0"?>
<stylesheet version="1.0" xmlns="http://www.w3.org/1999/XSL/Transform">
 <output method="xml" indent="yes" omit-xml-declaration="yes" />

 <template match="@*|node()">
  <copy>
   <apply-templates select="@*|node()"/>
  </copy>
 </template>

</stylesheet>'

end;

alter function interface.xsl_post ()
returns xml
begin

return 
'<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:db="http://unact.ru/database" 
 xmlns:ifc="http://unact.ru/interface"
 xmlns="http://unact.ru/database"
>

<xsl:output method="xml" indent="no" omit-xml-declaration="yes"  />

<xsl:template match="/" >
  <xsl:element name="request" namespace="http://unact.ru/database">
   <xsl:apply-templates select="//ifc:interface/*" />
  </xsl:element>
</xsl:template>


<xsl:template match="*">
 <xsl:copy>
   <xsl:for-each select="child::*[@inputId]">

     <xsl:variable name="attrValueAsIs">
       <xsl:choose>
         <xsl:when test="@editable and //ifc:formdata/ifc:vardata[@var=current()/@inputId]">
           <xsl:value-of select="//ifc:formdata/ifc:vardata[@var=current()/@inputId]/@value" />
         </xsl:when>
         <xsl:when test="@editable and . = 1">
           <xsl:value-of select="0" />
         </xsl:when>
         <xsl:otherwise>
           <xsl:value-of select="." />
         </xsl:otherwise>
       </xsl:choose>
     </xsl:variable>
     
     <xsl:variable name="attrValue">
      <xsl:choose>
         <xsl:when test="@type=''xs:decimal''">
           <xsl:value-of select="translate($attrValueAsIs,'', '','''')" />
         </xsl:when>
         <xsl:otherwise>
           <xsl:value-of select="$attrValueAsIs" />
         </xsl:otherwise>
      </xsl:choose>
     </xsl:variable>

     <xsl:if test="string-length($attrValue)>=0">
       <xsl:attribute name="{name()}"><xsl:value-of select="$attrValue" /></xsl:attribute>
     </xsl:if>

     <xsl:if test=". != $attrValue">
         <xsl:attribute name="modified">1</xsl:attribute>
     </xsl:if>

     <xsl:attribute name="intId"><xsl:value-of select="generate-id()" /></xsl:attribute>

   </xsl:for-each>

   <xsl:apply-templates select="@*|child::*[not(@inputId)]"/>

 </xsl:copy>
</xsl:template>


<xsl:template match="@inputId" />


<xsl:template match="@*">
  <xsl:copy/>
</xsl:template>


</xsl:stylesheet>
';
end;


alter function interface.xsl_makeid (in @request int)
returns xml
begin

return 
'<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:db="http://unact.ru/database" 
 xmlns:ifc="http://unact.ru/interface"
 xmlns="http://unact.ru/interface"
>


<xsl:output method="xml" indent="no" omit-xml-declaration="yes"  />

<xsl:template match="/">
 <xsl:element name="interface" namespace="http://unact.ru/interface">
   <xsl:attribute name="request_id">'+string(@request)+'</xsl:attribute>
   <xsl:apply-templates select="*"/>
 </xsl:element>
</xsl:template>

<xsl:template match="db:response//*">
 <xsl:copy>
   <xsl:for-each select="@intId"><xsl:copy/></xsl:for-each>
   <xsl:apply-templates select="@*|node()"/>
 </xsl:copy>
</xsl:template>



<xsl:template match="@intId" priority="20" />


<xsl:template match="//db:data//*/@*">
  <xsl:element name = "{name()}" namespace="http://unact.ru/database">

    <xsl:attribute name="inputId">
     <xsl:value-of select = "generate-id()" />
    </xsl:attribute>

    <xsl:attribute name="type">
     <xsl:value-of select = "//xs:schema//xs:element[@name=name(current()/..)]/*/xs:attribute[@name=name(current())]/@type" />
    </xsl:attribute>

    <xsl:if test="//xs:schema//xs:element[@name=name(current()/..)]/*/xs:attribute[@name=name(current()) and @editable]">
      <xsl:attribute name="editable">true</xsl:attribute>
    </xsl:if>

    <xsl:variable name="dbNewValue" select="//db:accepted//*[@intId=current()/../@intId]/@*[name()=name(current())]" />

    <xsl:choose>
      <xsl:when test="$dbNewValue">
        <xsl:value-of select="$dbNewValue"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:element>
</xsl:template>

<xsl:template match="@*">
  <xsl:copy/>
</xsl:template>

</xsl:stylesheet>
';
end;


alter function interface.xsl (in @device varchar(32) default 'pc')
returns xml
begin 

return
'<?xml version="1.0" encoding="windows-1251" ?>

<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:db="http://unact.ru/database" 
 xmlns:ifc="http://unact.ru/interface"
 xmlns="http://www.w3.org/1999/xhtml"
 exclude-result-prefixes="db ifc xs"
>

<xsl:output method="xml"
indent="yes"
omit-xml-declaration="yes"
doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" />

<xsl:template match="/">
 <xsl:apply-templates select="ifc:interface"/>
</xsl:template>


<xsl:template match="ifc:interface">

<html>
 <head>
    <meta http-equiv="Content-Type" content="text/html; charset=windows-1251" />
    <link rel="shortcut icon" href="/gallery_image/1" />
    <link rel="stylesheet" type="text/css" href="/css/main" />
 </head>
<body>
 <div id="menu">
   <a class="menupad">
     <xsl:if test="//db:data">
        <xsl:attribute name="href"/>
        <xsl:attribute name="onclick">document.getElementById(''data'').submit(); return false;</xsl:attribute>
     </xsl:if>Сохранить</a>
   <a class="menupad" href="?command=logoff">Выход</a>
 </div>
 <div id="main">
   <xsl:apply-templates select="//db:exception" />
   <xsl:apply-templates select="//db:accepted" />
   <xsl:apply-templates select="//db:data" />
 </div>
</body>
</html>

</xsl:template>


<xsl:template match="db:data">

 <xsl:variable name="tabletag" select="//xs:schema//xs:element[count(descendant::xs:element)=0]/@name" />
 <xsl:variable name="tablecols" select="count(//xs:schema//xs:element[@name=$tabletag]//xs:attribute)" />

 <form id="data" name="request-{/*/@request_id}" method="post" action="/xml?command=submit" >

  <input name="request_id" type="hidden" value="{/*/@request_id}" />

  <table>
    <tr class="header">
      <xsl:for-each select="//xs:schema//xs:element[@name=$tabletag]//xs:attribute">
       <th><xsl:choose>
             <xsl:when test="@caption"><xsl:value-of select="@caption" /></xsl:when>
             <xsl:otherwise><xsl:value-of select="@name" /></xsl:otherwise>
           </xsl:choose>
       </th>
      </xsl:for-each >
    </tr>
  
    <xsl:for-each select ="//db:data//*[not(@inputId)]">
     <tr>

         <xsl:variable name="currentNode" select="generate-id()" />
         <xsl:variable name="currentNodeName" select="name()" />

         <xsl:choose>

           <xsl:when test="name()=$tabletag">
             <xsl:attribute name="class">row<xsl:if test="//db:exception[@intId=current()/@intId]">, error</xsl:if></xsl:attribute>
             <xsl:for-each select="//xs:schema//xs:element[@name=name(current())]/*/xs:attribute">

               <xsl:variable name="currentValueNoformat"  select="//db:data//*[generate-id()=$currentNode]/*[name()=current()/@name]" />
               <xsl:variable name="currentValue">
                 <xsl:choose>
                   <xsl:when test="@type=''xs:decimal'' and format-number($currentValueNoformat,''#,##0.00'')!=''NaN''">
                      <xsl:value-of select="format-number($currentValueNoformat,''#,##0.00'')" />
                   </xsl:when>
                   <xsl:otherwise>
                      <xsl:value-of select="$currentValueNoformat" />
                   </xsl:otherwise>
                 </xsl:choose>
               </xsl:variable>

               <td>
                 <xsl:choose>
                  <xsl:when test="@editable">
                    <xsl:attribute name="class">editable</xsl:attribute>
  
                    <xsl:choose>
                      <xsl:when test="@type=''xs:boolean''">
                        <input type="checkbox" class="{@class}" value="1">
                          <xsl:attribute name="name">
                            <xsl:value-of select="//db:data//*[generate-id()=$currentNode]/*[name()=current()/@name]/@inputId"/>
                          </xsl:attribute>
                          <xsl:if test="$currentValue=''1''">
                            <xsl:attribute name="checked">checked</xsl:attribute>
                          </xsl:if>
                        </input>
                      </xsl:when>
                      <xsl:otherwise>
                          <input type="text" class="{@class}" maxlength="15">
                            <xsl:attribute name="name">
                             <xsl:value-of select="//db:data//*[generate-id()=$currentNode]/*[name()=current()/@name]/@inputId"/>
                           </xsl:attribute>
                           <xsl:attribute name="value">
                             <xsl:value-of select="$currentValue"/>
                           </xsl:attribute>
                          </input>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:attribute name="class"><xsl:value-of select="@class" /></xsl:attribute>
                     <xsl:value-of select="$currentValue" />
                  </xsl:otherwise>
                 </xsl:choose>
               </td>

             </xsl:for-each >
           </xsl:when>
           <xsl:otherwise>
             <xsl:attribute name="class">
               <xsl:value-of select="concat(''rowgroup'',count(//xs:schema//xs:element[@name=name(current())]/ancestor-or-self::xs:element))"/>
             </xsl:attribute>
             <td colspan="{$tablecols}">
               <span>
                <xsl:for-each select="//xs:schema//xs:element[@name=$currentNodeName]/*/xs:attribute">
                  <xsl:value-of select="//db:data//*[generate-id()=$currentNode]/*[name()=current()/@name]" />
                  <xsl:if test="position()!=last()"> :: </xsl:if>
                </xsl:for-each >
               </span>
             </td>
           </xsl:otherwise>
         </xsl:choose>
     </tr>
    </xsl:for-each>
    <tr class="totalsheader"> <td colspan="{$tablecols}"></td></tr>
    <tr class="totals">
      <xsl:for-each select="//xs:schema//xs:element[@name=$tabletag]//xs:attribute">
       <td><xsl:choose>
             <xsl:when test="@type=''xs:decimal''">
                <xsl:attribute name="id">total-<xsl:value-of select="@name" /></xsl:attribute>
                <xsl:attribute name="class"><xsl:value-of select="@class" /></xsl:attribute>
                <xsl:value-of select="format-number(sum(//db:data//*[name()=current()/@name and . != '''']),''#,##0.00'')" />
             </xsl:when>
           </xsl:choose>
       </td>
      </xsl:for-each >
    </tr>

  </table>
 </form>

</xsl:template>


<xsl:template match="db:exception">
  <div id="message" class="error">
   <xsl:value-of select="db:ErrorText" />
  </div>
</xsl:template>

<xsl:template match="db:accepted">
  <div id="message">
    Данные успешно сохранены. Изменено (<xsl:value-of select="count(db:modified)" />) записей. (<xsl:value-of select="count(db:deleted)" />) записей удалено.
  </div>
</xsl:template>

</xsl:stylesheet>'
end
