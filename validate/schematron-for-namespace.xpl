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
  name="schematron-for-namespace" type="sbf:schematron-for-namespace">

  <p:import href="http://transpect.io/schematron/xpl/oxy-schematron.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:input port="schema">
    <p:documentation>An expanded NVDL schema that associates Schematron validations with namespace URIs. 
      Alternatively, an assembled Schematron schema.</p:documentation>
  </p:input>
  <p:input port="source" primary="true">
    <p:documentation>Zip Manifest or other XML file for which Schematron checks exist.</p:documentation>
  </p:input>
  <p:input port="contents" sequence="true">
    <p:documentation>If the input to invoking validation pipeline was a zip, this port has its contents
    with base-uri document properties that match c:entry/@href in the manifest.</p:documentation>
  </p:input>
  
  <p:output port="result" primary="true" pipe="result@validate-if-schematron-exists-for-namespace"/>
  <p:output port="result-contents" sequence="true" pipe="result@process-contents"/>
  <p:output port="report" pipe="report@validate-if-schematron-exists-for-namespace report@process-contents" sequence="true"/>
  
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:variable name="namespace-uri" as="xs:string" select="namespace-uri(/*) => string()"/>
  <p:variable name="local-name" as="xs:string" select="local-name(/*)"/>

  <p:identity name="schema-into-focus">
    <p:with-input pipe="schema@schematron-for-namespace"/>
  </p:identity>

  <p:choose name="schematron-from-nvdl-or-standalone">
    <p:when test="exists(/nvdl:rules)">
      <p:output port="result" sequence="true"/>
      <p:identity>
        <p:with-input select="/nvdl:rules/nvdl:namespace[@ns = $namespace-uri]/nvdl:validate/sch:schema"/>
      </p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="result" sequence="true"/>
      <p:identity/>
    </p:otherwise>
  </p:choose>
  
  <p:count name="zero-or-one-schematron"/>

  <p:choose name="validate-if-schematron-exists-for-namespace">
    <p:when test="/c:result = '0'">
      <p:documentation>No Schematron for namespace. Return a c:ok document on the report port 
        and the source port unchanged on the result port.</p:documentation>
      <p:output port="report">
        <p:inline><c:ok reason="no-schematron-for-namespace"/></p:inline>
      </p:output>
      <p:output port="result" primary="true"/>
      <p:identity>
        <p:with-input pipe="source@schematron-for-namespace"/>
      </p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="report" pipe="result@set-svrl-base-uri"/>
      <p:output port="result" primary="true" pipe="result@validate-with-schematron"/>
      <p:identity name="source-into-focus">
        <p:with-input pipe="source@schematron-for-namespace"/>
      </p:identity>
      <p:variable name="base-uri" as="xs:string?" select="p:document-property(., 'base-uri')"/>
      <tr:oxy-validate-with-schematron name="validate-with-schematron" p:message="val base uri: {$base-uri}, name:
        {/*/name()}">
        <p:with-option name="parameters" select="map{xs:QName('allow-foreign'): 'true'}"/>
        <p:with-input port="schema" pipe="result@schematron-from-nvdl-or-standalone"/>
      </tr:oxy-validate-with-schematron>
      <p:identity name="svrl-into-focus">
        <p:with-input pipe="report@validate-with-schematron"/>
      </p:identity>
      <p:set-properties name="set-svrl-base-uri">
        <p:with-option name="properties" select="map{xs:QName('base-uri'): ($base-uri || '.val')}"/>
      </p:set-properties>
      <tr:store-debug name="store-svrl">
        <p:with-option name="active" select="$debug"/>
        <p:with-option name="base-uri" select="$debug-dir-uri"/>
        <p:with-option name="pipeline-step" select="'schematron_pass1/' || $base-uri => replace('^.+/', '') || '.svrl'"/>
      </tr:store-debug>
      <p:sink name="sink1"/>
    </p:otherwise>
  </p:choose>

  <p:if test="$namespace-uri = 'http://www.w3.org/ns/xproc-step' and $local-name = 'archive'"
    name="process-contents">
    <p:output port="report" sequence="true" pipe="report@process-xml-entries"/>
    <p:output port="result" primary="true" sequence="true">
      <p:documentation>This result will become the new contents “stream” that will go into the output zip. Even if the
        files were renamed for the output zip, the base-uri property will stay the same. The renaming only occurs 
      in the c:entry/@name attribute of the archive manifest.</p:documentation>
    </p:output>
    <p:for-each name="process-xml-entries">
      <p:with-input pipe="contents@schematron-for-namespace"/>
      <p:output port="report" pipe="report@is-xml" sequence="true"/>
      <p:output port="result" primary="true"/>
      <p:variable name="base-uri" as="xs:string" select="p:document-property(., 'base-uri')"/>
      <p:variable name="is-xml" as="xs:boolean" select="$base-uri = /c:archive/c:entry[@namespace-uri]/@href"/>
      <p:choose name="is-xml">
        <p:when test="$is-xml">
          <p:output port="report" pipe="report@recursive-schematron-for-namespace"/>
          <p:output port="result" primary="true"/>
          <sbf:schematron-for-namespace name="recursive-schematron-for-namespace">
            <p:with-input port="schema" pipe="schema@schematron-for-namespace"/>
            <p:with-input port="contents">
              <p:empty/>
            </p:with-input>
            <p:with-option name="debug" select="$debug"/>
            <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
          </sbf:schematron-for-namespace>
        </p:when>
        <p:otherwise>
          <p:output port="result" primary="true"/>
          <p:output port="report" sequence="true">
            <p:empty/>
          </p:output>
          <p:identity/>
        </p:otherwise>
      </p:choose>
    </p:for-each>
  </p:if>

  <p:sink name="sink0"/>

</p:declare-step>
