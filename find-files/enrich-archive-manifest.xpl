<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  version="3.1" name="enrich-archive-manifest"
  type="sbf:enrich-archive-manifest">
  <p:input port="source" primary="true" content-types="application/zip"/>
  <p:output port="result" primary="true">
    <p:documentation>The enhanced zip manifest</p:documentation>
  </p:output>
  <p:output port="contents" sequence="true" pipe="result@unarchive"/>
<!--  <p:option name="zip-file" as="xs:string"/>
  <p:load href="{$zip-file}" name="load-zip"/>-->
  <p:unarchive name="unarchive"/>
  <p:sink name="sink0"/>
  <p:archive-manifest name="am">
    <p:with-input pipe="source@enrich-archive-manifest"/>
<!--    <p:with-input pipe="result@load-zip"/>-->
  </p:archive-manifest>
  <p:set-properties name="set-manifest-base-uri">
    <p:with-option name="properties" pipe="source@enrich-archive-manifest" 
      select="map{xs:QName('base-uri'): p:document-property(., 'base-uri') || '.manifest.xml'}"/>
  </p:set-properties>
  <p:viewport match="c:entry[@content-type = 'application/xml' or ends-with(@content-type, '+xml')]" name="manifest-vp">
    <p:variable name="entry-href" as="xs:string" select="/c:entry/@href"/>
    <p:split-sequence name="select-current-entry-xml">
      <p:with-input pipe="result@unarchive"/>
      <p:with-option name="test" select="'base-uri(/*) = ''' || $entry-href || ''''"/>
    </p:split-sequence>
    <p:variable name="namespace-uri" as="xs:string" select="namespace-uri(/*) => string()"/>
    <p:add-attribute attribute-name="namespace-uri" attribute-value="{$namespace-uri}">
      <p:with-input pipe="current@manifest-vp"/>
    </p:add-attribute>
    <p:insert name="insert-xml-into-manifest" position="first-child">
      <p:with-input port="insertion" pipe="matched@select-current-entry-xml"/>
    </p:insert>
  </p:viewport>
</p:declare-step>