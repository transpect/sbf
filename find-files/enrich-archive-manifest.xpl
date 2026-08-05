<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  xmlns:tr="http://transpect.io"
  version="3.1" name="enrich-archive-manifest"
  type="sbf:enrich-archive-manifest">
  
  <p:import href="../helper/merge-into-archive-manifest.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:input port="source" primary="true" content-types="application/zip"/>
  <p:output port="result" primary="true">
    <p:documentation>The enhanced zip manifest</p:documentation>
  </p:output>
  <p:output port="contents" sequence="true" pipe="result@unarchive"/>

  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:unarchive name="unarchive"/>
  <p:sink name="sink0"/>
  <p:archive-manifest name="am">
    <p:with-input pipe="source@enrich-archive-manifest"/>
  </p:archive-manifest>

  <p:set-properties name="set-manifest-base-uri">
    <p:with-option name="properties" pipe="source@enrich-archive-manifest" 
      select="map{xs:QName('base-uri'): p:document-property(., 'base-uri') || '.manifest.xml'}"/>
  </p:set-properties>

  <sbf:merge-into-archive-manifest>
    <p:with-input port="insertions" pipe="result@unarchive"/>
  </sbf:merge-into-archive-manifest>
  
  <tr:store-debug name="store-enriched-manifest" active="{$debug}" base-uri="{$debug-dir-uri}"
    pipeline-step="enrich-manifest/{p:document-property(., 'base-uri') => replace('^.+/', '')}.manifest.xml"/>
  
</p:declare-step>