<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:nvdl="http://purl.oclc.org/dsdl/nvdl/ns/structure/1.0"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:cx="http://xmlcalabash.com/ns/extensions"
  xmlns:tr="http://transpect.io"
  version="3.1" 
  name="val-zip" type="sbf:validation-archive">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  <p:import href="validate.xpl"/>
  
  <p:documentation>For input port (and for $input-uri) documentation, see validate.xpl</p:documentation>
  
  <p:input port="schema"/>
  <p:input port="source" content-types="xml application/zip" sequence="true" primary="true"/>
  <p:input port="svrl2html" href="svrl2html.xsl"/>

  <p:option name="input-uri" as="xs:string?" required="false"/>
    
  <!--<p:output port="errors" sequence="true">
    <p:pipe port="result" step="insert-post-fix-svrl"/>
  </p:output>-->
  <!--<p:output port="shortreport" sequence="true">
    <p:pipe port="result" step="html2shortreport"/>
  </p:output>-->

  <p:output port="result" primary="true" content-types="application/zip">
    <p:documentation>A zip that contains the fixed input plus the reports, an optional HTML rendering 
      and also the original input.</p:documentation>
  </p:output>
  
  <p:option name="keep-srcpath" select="'pi_changed'">
    <p:documentation>Whether to keep srcpath attributes in the result. Possible values: 'no' (remove them),
    'pi_always': keep them as processing instructions, 'pi_changed': only keep them if the current path differs,
    'yes': keep them</p:documentation>
  </p:option>
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <sbf:batch-val name="validate" debug="{$debug}" debug-dir-uri="{$debug-dir-uri}">
    <p:with-option name="input-uri" select="$input-uri"/>
    <p:with-input port="schema" pipe="schema@val-zip"/>
    <p:with-input port="source" pipe="source@val-zip"/>
    <p:with-input port="svrl2html" pipe="svrl2html@val-zip"/>
  </sbf:batch-val>

  <p:variable name="input-base-uri" as="xs:string" pipe="input@validate" 
    select="p:document-property(., 'base-uri')"/>
  <p:variable name="input-is-zip" as="xs:boolean" select="ends-with($input-base-uri, '.zip')"/>
  <p:variable name="base-dir-uri-for-zips" as="xs:string" select="$input-base-uri || '/'"/>
  
  <p:choose name="conditionally-adjust-uris">
    <p:when test="$input-is-zip">
      <p:output port="input" pipe="result@adjust-input-uri"/>
      <p:output port="htmlreport" pipe="result@adjust-htmlreport-uri"/>
      <p:output port="result" primary="true"/>
      <p:identity><p:with-input pipe="input@validate"/></p:identity>
      <p:set-properties name="adjust-input-uri">
        <p:with-option name="properties"
          select="map{xs:QName('base-uri'): 
              p:document-property(., 'base-uri') => replace('^.+/([^/]+)$', $base-dir-uri-for-zips || '$1')}"/>
      </p:set-properties>
      <p:identity><p:with-input pipe="htmlreport@validate"/></p:identity>
      <p:set-properties name="adjust-htmlreport-uri">
        <p:with-option name="properties"
          select="map{xs:QName('base-uri'): 
              p:document-property(., 'base-uri') => replace('^.+/([^/]+)$', $base-dir-uri-for-zips || '$1')}"/>
      </p:set-properties>
      <p:identity><p:with-input pipe="result@validate"/></p:identity>
      <p:set-properties name="adjust-result-uri">
        <p:with-option name="properties" 
          select="map{xs:QName('base-uri'): 
              p:document-property(., 'base-uri') => replace('^.+/([^/]+)$', $base-dir-uri-for-zips || '$1')}"/>
      </p:set-properties>
    </p:when>
    <p:otherwise>
      <p:output port="input" pipe="input@validate"/>
      <p:output port="htmlreport" pipe="htmlreport@validate"/>
      <p:output port="result" primary="true"/>
      <p:identity><p:with-input pipe="result@validate"/></p:identity>
    </p:otherwise>
  </p:choose>
  
  <p:identity message="ADJUSTED OUTPUT BASE URI: {p:document-property(., 'base-uri')}"/>
  
  <p:archive name="create-output-zip" relative-to="{$input-base-uri}" message="relative-to: {$input-base-uri}">
    <p:with-input port="source" 
      pipe="input@conditionally-adjust-uris result@conditionally-adjust-uris htmlreport@conditionally-adjust-uris rendering@validate"/>
  </p:archive>

</p:declare-step>
