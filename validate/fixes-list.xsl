<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  exclude-result-prefixes="xs sch svrl"
  version="3.0">
  <xsl:key name="by-id" match="*[@id]" use="@id"/>
  <xsl:key name="by-test-id" match="*[@test-id]" use="@test-id"/>
  
  <xsl:mode name="pos" on-no-match="shallow-copy"/>
  
  <xsl:variable name="svrl-doc" as="document-node(element(svrl:schematron-output))" 
    select="collection()[svrl:schematron-output]"/>
  
  <xsl:variable name="schema_tron" as="document-node(element(sch:schema))" select="collection()[sch:schema]"/>
  
  <xsl:variable name="error-ids-with-fixes" as="xs:string*"
    select="$schema_tron//(sch:assert | sch:report)[sbf:xsl-fix | sbf:xproc-fix]/@id"/>
  
  <xsl:variable name="svrl-ids" as="xs:string*" 
    select="distinct-values($svrl-doc/svrl:schematron-output
                                       /(svrl:failed-assert | svrl:successful-report)/@id[. = $error-ids-with-fixes])"/>
  
  <xsl:template name="main">
    <xsl:message select="'SVRL-count: ' || count($svrl-doc/svrl:schematron-output)"/>
    <xsl:apply-templates select="$svrl-doc/svrl:schematron-output">
      <xsl:with-param name="schematron" as="document-node(element(sch:schema))" select="$schema_tron" tunnel="yes"/>
      <xsl:with-param name="svrl-ids" as="xs:string*" select="$svrl-ids" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="/sbf:fixes-list/*/@*[1]" mode="pos">
    <xsl:attribute name="pos" select="index-of(../../sbf:* ! generate-id(.), generate-id(..))"/>
    <xsl:next-match/>
  </xsl:template>
  
  
  <xsl:template match="/svrl:schematron-output">
    <xsl:param name="schematron" tunnel="yes" as="document-node(element(sch:schema))"/>
    <xsl:param name="svrl-ids" as="xs:string*" tunnel="yes"/>
    <xsl:variable name="svrl" as="document-node()" select=".."/>
    <xsl:variable name="prelim" as="document-node(element(sbf:fixes-list))">
      <xsl:document>
        <sbf:fixes-list>
          <xsl:attribute name="xml:base" select="$svrl ! base-uri(.) ! replace(., '\.val$', '.fixes-list')"/>
          <xsl:for-each-group select="$svrl-ids ! key('by-test-id', ., $svrl)[1] 
                                                ! sbf:prepend-prerequisites(., $svrl, $schematron)" 
                              group-by="sbf:fix-usage-signature(.)">
            <xsl:apply-templates select="."/>
          </xsl:for-each-group>
        </sbf:fixes-list>
      </xsl:document>
    </xsl:variable>
    <xsl:apply-templates select="$prelim" mode="pos"/>
  </xsl:template>
  
  <xsl:function name="sbf:prepend-prerequisites" as="element(*)*">
    <xsl:param name="fix" as="element(*)*"/>
    <xsl:param name="svrl" as="document-node(element(svrl:schematron-output))"/>
    <xsl:param name="schematron" as="document-node(element(sch:schema))"/>
    <xsl:for-each select="$fix/@depends-on (: id of an sch:assert or sch:report with an sbf:xsl-fix :)">
      <xsl:variable name="dependencies-found-in-svrl" as="element(*)*"
        select="tokenize(., '\s+') ! key('by-test-id', ., $svrl)[1]"/>
      <xsl:variable name="fallback-dependencies-found-in-schematron" as="element(*)*"
        select="tokenize(., '\s+')[not(. = $dependencies-found-in-svrl/@test-id)] ! key('by-test-id', ., $schematron)[1]"/>
      <xsl:sequence select="sbf:prepend-prerequisites(($dependencies-found-in-svrl, $fallback-dependencies-found-in-schematron), $svrl, $schematron)"/>
    </xsl:for-each>
    <xsl:apply-templates select="$fix">
      <xsl:with-param name="schematron" select="$schematron" as="document-node(element(sch:schema))" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:function>
  
  <xsl:function name="sbf:fix-usage-signature" as="xs:string">
    <xsl:param name="fix" as="element(*)"/>
    <xsl:sequence select="string-join($fix/(sbf:xsl-uri, .) !
                                        (string(@href), string(@mode), 
                                         sbf:param/@* ! (name(), string(.))),
                                      '__')"/>
  </xsl:function>
  
  <xsl:template match="sbf:xsl-fix | sbf:xproc-fix">
    <xsl:param name="schematron" as="document-node(element(sch:schema))" tunnel="yes"/>
    <xsl:if test="local-name(..) = ('report', 'assert') and empty(../@id)">
      <xsl:message terminate="yes" select="'This schematron element neeeds an ID: ', .."/>
    </xsl:if>
    <xsl:variable name="fix-in-schematron" select="key('by-test-id', @test-id, $schematron)[1]"/>
    <!--<xsl:if test="exists(sbf:param)">
      <xsl:message select="'fixes-list: ', sbf:param"/>
    </xsl:if>-->
    <xsl:copy>
      <xsl:attribute name="href" select="resolve-uri(@href, base-uri($fix-in-schematron))"/>
      <xsl:copy-of select="@* except @href, node()"/>
      <!-- apply-templates of sbf:param does not work, probably due to a Calabash bug.
                This and other strange things only happen when sbf:xsl-fix occur both in Schematron and XVRL documents. -->  
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>