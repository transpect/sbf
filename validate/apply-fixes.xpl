<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:nvdl="http://purl.oclc.org/dsdl/nvdl/ns/structure/1.0"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:tr="http://transpect.io"
  version="3.1" 
  name="apply-fixes" type="sbf:apply-fixes">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  <p:import href="../helper/params-to-json.xpl"/>
  
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

  <p:output port="result" primary="true" pipe="result@conditionally-recurse"/>
  <p:output port="result-contents" sequence="true" pipe="result-contents@conditionally-recurse"/>
  
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:for-each name="apply-single-fix">
    <p:with-input select="/sbf:fixes-list/*[1]"/>
    <p:output port="result" primary="true"/>
    <p:output port="result-contents" sequence="true" pipe="result-contents@xsl-or-xproc"/>
    <p:variable name="iteration-position" select="p:iteration-position()"/>
    <p:choose name="xsl-or-xproc">
      <p:when test="exists(/sbf:xsl-fix)">
        <p:output port="result" primary="true"/>
        <p:output port="result-contents" sequence="true"><p:empty/></p:output>
        <p:variable name="fix-xsl-href" select="/*/@href"/>
        <p:variable name="fix-xsl-mode" select="xs:QName(/*/@mode)" as="xs:QName"/>
        <p:for-each name="params">
          <p:output port="result" primary="true" content-types="application/json"/>
          <p:with-input select="/sbf:xsl-fix/c:param-set"/>
          <p:cast-content-type content-type="application/json"/>
        </p:for-each>
        <p:variable name="params" select="collection()" collection="true" as="map(*)*"/>
        <p:load name="load-xsl" href="{$fix-xsl-href}"/>
        <p:sink name="sink4"/>
        <p:xslt name="fix-current-source-doc">
          <p:with-option name="initial-mode" select="$fix-xsl-mode"/>
          <p:with-option name="parameters" select="$params"/>
          <p:with-input port="source" pipe="source@apply-fixes"/>
          <p:with-input port="stylesheet" pipe="result@load-xsl"/>
        </p:xslt>
        <tr:store-debug name="store-patched" active="{$debug}" base-uri="{$debug-dir-uri}"
          pipeline-step="{string-join(('apply-fixes/apply-xsl-fix', $iteration-position,
                                       replace(base-uri(/*), '^.+/(.+?)\.xml$', '$1'), 
                                       replace($fix-xsl-href, '^.+/(.+?)\.xsl$', '$1'),
                                       replace(string($fix-xsl-mode), ':', '_')),
                                      '__')}"/>
      </p:when>
      <p:when test="exists(/sbf:xproc-fix)">
        <p:documentation>All XProc fixes, even if they only fix a single image file, have a primary input port
          that expects XML. It can be a c:archive zip manifest or an XML file that represents image properties.
        If the fixes can be called within zip processing, they should always return the manifest and the complete
        contents. The sbf:xproc-fix element in SVRL conveys information such as the XSLTs to run on namespaced documents, 
        options for the pipeline, and parameters for the XSLT stylesheets. It will be passed to the fix pipeline 
        on the this-fix-from-svrl port.</p:documentation>
        <p:documentation>An sbf:xproc-fix in XVRL may specify in the operates-on attribute on which kind of data it 
          operates. If this attribute is present and the XProc pipeline referenced in href contains
          an p:pipeinfo/sbf:operates-on element, the content of this element must match the operates-on attribute in
          the SVRL.</p:documentation>
        <p:documentation>XProc fixes that operate on 'expanded-archive-manifest-and-contents' typically use a p:viewport
          to transform the XML contents that are expanded below the c:entry elements. Then they iterate over the
          contents port and replace the XML documents with the possibly transformed ones from the expanded manifest.
        Alternatively, the fix can transform the XML documents in contents and replace the expanded XML below c:entry.</p:documentation>
        <p:documentation>XProc fixes that operate on 'file-in-contents' typically use a split-sequence on contents
          in order to select the file by its base-uri property. This base URI is c:entry/@href. The Schematron 
          check must make sure that this href is passed to the fix as an sbf:param, by convention with name="href"
          and the value of this href. It cannot be inserted by sch:value-of because sch:value-of is only valid
          immediately below sch:report or sch:assert. Use xsl:value-of in order to insert the parameter value.</p:documentation>
        <p:output port="result" primary="true"/>
        <p:output port="result-contents" sequence="true" pipe="result-contents@run-fix"/>
        <p:run name="run-fix">
          <p:with-input href="{/sbf:xproc-fix/@href}"/>
          <p:run-input port="source" pipe="source@apply-fixes" primary="true"/>
          <p:run-input port="contents" pipe="contents@apply-fixes" />
          <p:run-input port="this-fix-from-svrl" pipe="current@apply-single-fix"/>
          <p:output port="result" primary="true"/>
          <p:output port="result-contents" sequence="true"/>
        </p:run>
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
