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
  name="merge-into-archive-manifest" type="sbf:merge-into-archive-manifest">
  
  <p:input port="source" primary="true">
    <p:documentation>An archive manifest, c:archive. An XML document on the insertions port will replace the old 
      c:entry content (if present) that has the same base URI.</p:documentation>
  </p:input>
  
  <p:input port="insertions" sequence="true"/>
  
  <p:output port="result" primary="true"/>
  
  <p:identity>
    <p:with-input pipe="source@merge-into-archive-manifest"/>
  </p:identity>
  
  <p:viewport match="c:entry[@content-type = 'application/xml' or ends-with(@content-type, '+xml')]" name="manifest-vp">
    <p:variable name="entry-href" as="xs:string" select="/c:entry/@href"/>
    <p:identity message="entry-href: {$entry-href}"></p:identity>
    <p:split-sequence name="select-current-entry-xml" initial-only="true"
      test="p:urify(base-uri(.)) = '{$entry-href}'">
      <p:with-input pipe="insertions@merge-into-archive-manifest"/>
    </p:split-sequence>
    <p:variable name="namespace-uri" as="xs:string" select="namespace-uri(collection()[1]/*) => string()" 
      collection="true"/>
    <p:identity>
      <p:with-input pipe="current@manifest-vp"/>
    </p:identity>
    <p:add-attribute attribute-name="namespace-uri" attribute-value="{$namespace-uri}"/>
    <p:delete match="/c:entry/*"/>
    <p:insert name="insert-xml-into-manifest" position="first-child">
      <p:with-input port="insertion" pipe="matched@select-current-entry-xml"/>
    </p:insert>
  </p:viewport>

</p:declare-step>
