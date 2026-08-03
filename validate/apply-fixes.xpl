<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:nvdl="http://purl.oclc.org/dsdl/nvdl/ns/structure/1.0"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:tr="http://transpect.io"
  version="3.1" 
  name="apply-fixes" type="sbf:apply-fixes">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:input port="fixes-list" primary="true">
    <p:documentation>An sbf:fixes-list with sbf:xsl-fix or sbf:xproc-fix child elements. This step applies the
    first fix and calls itself recursively with sn sbf:fixes-list in which the first fix is removed, until
    no more fixes are left.</p:documentation>
  </p:input>
  <p:input port="source">
    <p:documentation>A Schematron-validated XML document with srcpath attributes. These attributes indicate
    the original XPath locations so they can be compared with the post-fix locations in order to determine whether
    a given error is detected again at the new location (fix unsuccessful) or whether it isn’t detected again
    (fix successful).</p:documentation>
  </p:input>
  <p:input port="contents" content-types="any" sequence="true">
    <p:documentation>When the original input is a zip file, source is a zip manifest and here are the contained
      files. If source is an XML file other than an archive manifest, contents will always be empty.</p:documentation>
  </p:input>

  <p:output port="result" primary="true"/>
  <p:output port="result-contents" sequence="true"/>
  
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:for-each name="apply-single-fix">
    <p:with-input select="/sbf:fixes-list/*[1]"/>
    <p:output port="result" primary="true"/>
    <p:output port="result-contents" sequence="true"><p:empty/></p:output>
    <p:variable name="iteration-position" select="p:iteration-position()"/>
    <p:choose name="xsl-or-xproc">
      <p:when test="exists(/sbf:xsl-fix)">
        <p:output port="result" primary="true"/>
        <p:output port="result-contents" sequence="true"><p:empty/></p:output>
        <p:variable name="fix-xsl-href" select="/*/@href"/>
        <p:variable name="fix-xsl-mode" select="xs:QName(/*/@mode)" as="xs:QName"/>
        <p:load name="load-xsl" href="{$fix-xsl-href}"/>
        <p:sink name="sink4"/>
        <p:xslt name="fix-current-source-doc">
          <!--<p:with-option name="output-base-uri" select="replace(base-uri(/*), '(\.fixed)?\.xml$', '.fixed.xml')">
            <p:pipe port="source" step="apply-fixes-recursion-decl"/>
          </p:with-option>-->
          <p:with-option name="initial-mode" select="$fix-xsl-mode"/>
          <p:with-input port="source" pipe="source@apply-fixes"/>
          <!-- To do: turn c:param-set into JSON, blocked by https://codeberg.org/xmlcalabash/xmlcalabash3/issues/790
            <p:input port="parameters" select="/sbf:xsl-fix/c:param-set">
            <p:pipe port="current" step="fix-source"/>
          </p:input>-->
          <p:with-input port="stylesheet" pipe="result@load-xsl"/>
        </p:xslt>
        <!--<p:add-attribute name="make-fixed-xml-base-explicit" attribute-name="xml:base" match="/*">
          <p:documentation>output-base-uri apparently doesn't change as requested</p:documentation>
          <p:with-option name="attribute-value" select="replace(base-uri(/*), '(\.fixed)?\.xml$', '.fixed.xml')"/>
        </p:add-attribute>-->
        <!--<cx:message>
        <p:with-option name="message" select="'VVVVVVVVVVV ', ' ;; &#xa;', base-uri(/*), ' :: ', replace(base-uri(/*), '(\.fixed)?\.xml$', '.fixed.xml')"/>
      </cx:message>-->
        <tr:store-debug name="store-patched" active="{$debug}" base-uri="{$debug-dir-uri}"
          pipeline-step="{string-join(('apply-fix', $iteration-position,
                                       replace(base-uri(/*), '^.+/(.+?)\.xml$', '$1'), 
                                       replace($fix-xsl-href, '^.+/(.+?)\.xsl$', '$1'),
                                       replace(string($fix-xsl-mode), ':', '_')),
                                      '__')}"/>
      </p:when>
      <p:when test="exists(/sbf:xproc-fix)">
        <p:output port="result" primary="true"/>
        <p:output port="result-contents" sequence="true"><p:empty/><!-- to do --></p:output>
        <p:identity>
          <p:with-input pipe="source@apply-fixes"/>
        </p:identity>
      </p:when>
    </p:choose>
  </p:for-each>
  
  <p:count name="count-fixed-doc"/>
  <p:choose name="conditionally-recurse">
    <p:when test=". = 0">
      <p:output port="result" primary="true"/>
      <p:output port="result-contents" sequence="true" pipe="contents@apply-fixes"/>
      <p:documentation>no more fixes, return souce</p:documentation>
      <p:identity><p:with-input port="source" pipe="source@apply-fixes"/></p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="result" primary="true"/>
      <p:output port="result-contents" sequence="true" pipe="result-contents@encore"/>
      <p:delete match="/sbf:fixes-list/*[1]"><p:with-input port="source" pipe="fixes-list@apply-fixes"/></p:delete>
      <sbf:apply-fixes name="encore">
        <p:with-input port="source" pipe="result@apply-single-fix"/>
        <p:with-input port="contents" pipe="result-contents@apply-single-fix"/>
        <p:with-option name="debug" select="$debug"/>
        <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
      </sbf:apply-fixes>
    </p:otherwise>
  </p:choose>
  
</p:declare-step>
