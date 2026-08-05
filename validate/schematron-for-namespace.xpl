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
  name="schematron-for-namespace" type="sbf:schematron-for-namespace">

  <p:import href="http://transpect.io/schematron/xpl/oxy-schematron.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  <p:import href="add-srcpaths.xpl"/>
  <p:import href="fixes-list.xpl"/>
  <p:import href="apply-fixes.xpl"/>
  
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
  
  <p:output port="result" primary="true" pipe="result@validate-if-schematron-exists-for-namespace">
    <p:documentation>The updated zip manifest or XML file that appeared on source.</p:documentation>
  </p:output>
  <p:output port="result-contents" sequence="true" pipe="result-contents@process-contents"/>
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
      <p:output port="result" sequence="true" primary="true"/>
      <p:output port="params" sequence="true" pipe="result@param-sets" content-types="application/json"/>
      <p:for-each name="param-sets">
        <p:with-input select="/nvdl:rules/nvdl:namespace[@ns = $namespace-uri]/nvdl:validate/c:param-set"/>
        <p:output port="result" content-types="application/json"/>
        <p:cast-content-type content-type="application/json"/>
      </p:for-each>
      <p:identity>
        <p:with-input select="/nvdl:rules/nvdl:namespace[@ns = $namespace-uri]/nvdl:validate/sch:schema" 
          pipe="result@schema-into-focus"/>
      </p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="result" sequence="true" primary="true"/>
      <p:output port="params" sequence="true"><p:empty/></p:output>
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
      <p:output port="result-contents" pipe="contents@schematron-for-namespace" sequence="true"/>
      <p:output port="result" primary="true"/>
      <p:identity>
        <p:with-input pipe="source@schematron-for-namespace"/>
      </p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="report" pipe="result@set-svrl-base-uri"/>
      <p:output port="result" primary="true" pipe="result@apply-fixes"/>
      <p:output port="result-contents" pipe="result-contents@apply-fixes" sequence="true"/>
      <sbf:add-srcpaths name="add-srcpaths">
        <p:with-input pipe="source@schematron-for-namespace"/>
      </sbf:add-srcpaths>
      <p:variable name="base-uri" as="xs:string?" select="p:document-property(., 'base-uri')"/>
      <p:variable name="params" as="map(*)*" pipe="params@schematron-from-nvdl-or-standalone" 
        select="collection()" collection="true"/> 
      <tr:oxy-validate-with-schematron name="validate-with-schematron" p:message="val base uri: {$base-uri}, name:
        {/*/name()}">
        <p:with-option name="parameters" 
          select="map:merge((map{xs:QName('allow-foreign'): 'true'}, $params), map{'duplicates': 'combine'})"/>
        <p:with-input port="schema" pipe="result@schematron-from-nvdl-or-standalone"/>
      </tr:oxy-validate-with-schematron>
      <p:identity name="svrl-into-focus"><p:with-input pipe="report@validate-with-schematron"/></p:identity>
      <p:set-properties name="set-svrl-base-uri">
        <p:with-option name="properties" select="map{xs:QName('base-uri'): ($base-uri || '.val')}"/>
      </p:set-properties>
      <tr:store-debug name="store-svrl" active="{$debug}" base-uri="{$debug-dir-uri}"
        pipeline-step="schematron_pass1/{$base-uri => replace('^.+/', '')}.svrl"/>
      
      <sbf:fixes-list debug="{$debug}" debug-dir-uri="{$debug-dir-uri}" name="fixes-list">
        <p:with-input port="schema" pipe="result@schematron-from-nvdl-or-standalone"/>
      </sbf:fixes-list>
      <p:identity message="SFNTOP {/*/name()}">
        <p:with-input pipe="contents@schematron-for-namespace"></p:with-input>
      </p:identity>
      
      <p:count/>
      
      <p:identity message="SFNSIZE {.}">
        <p:with-input pipe="result@fixes-list"></p:with-input>
      </p:identity>
      
      <sbf:apply-fixes name="apply-fixes">
        <p:with-input port="source" pipe="result@add-srcpaths"/>
        <p:with-input port="contents" pipe="contents@schematron-for-namespace"/>
      </sbf:apply-fixes>
      
      <p:count>
        <p:with-input port="source" pipe="result-contents@apply-fixes"/>
      </p:count>
      
      <p:identity message="SFNSIZE-after {.}">
      </p:identity>
      <!--<tr:oxy-validate-with-schematron name="validate-with-schematron_pass2">
        <p:with-option name="parameters" select="map{xs:QName('allow-foreign'): 'true'}"/>
        <p:with-input port="schema" pipe="result@schematron-from-nvdl-or-standalone"/>
      </tr:oxy-validate-with-schematron>-->
    </p:otherwise>
  </p:choose>

  <p:choose name="process-contents">
    <p:when test="$namespace-uri = 'http://www.w3.org/ns/xproc-step' and $local-name = 'archive'">
      <p:output port="report" sequence="true" pipe="report@process-xml-entries"/>
      <p:output port="result-contents" primary="true" sequence="true">
        <p:documentation>This result will become the new contents “stream” that will go into the output zip. Even if the
          files were renamed for the output zip, the base-uri property will stay the same. The renaming only occurs 
        in the c:entry/@name attribute of the archive manifest.</p:documentation>
      </p:output>
      <p:for-each name="process-xml-entries">
        <p:with-input pipe="result-contents@validate-if-schematron-exists-for-namespace"/>
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
    </p:when>
    <p:otherwise>
      <p:output port="report" sequence="true">
        <p:empty/>
      </p:output>
      <p:output port="result-contents" primary="true" sequence="true">
        <p:empty/>
      </p:output>
      <p:sink/>
    </p:otherwise>
  </p:choose>

</p:declare-step>
