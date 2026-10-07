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
  <p:import href="http://transpect.io/xproc-util/data-uri/xpl/archive-data-uri-map.xpl"/>
  <p:import href="add-srcpaths.xpl"/>
  <p:import href="fixes-list.xpl"/>
  <p:import href="apply-fixes.xpl"/>
  <p:import href="../render/render.xpl"/>
  
  <p:documentation>Will select schemas for the given namespace from NVDL, or, if Schematron is supplied
    instead of NVDL, will use this Schematron. In both cases, the schematron is expected to be assembled
    already (sbf:extends are expanded), and in the case of NVDL the expanded Schematron schema is included 
    below nvdl:namespace/nvdl:validate.
    Although this step is called schematron-for-namespace, it is planned that additional schema validations,
    before or after the fixes have been applied, can be performed. These future validations may be either 
    specified by additional nvdl:validate instructions or by acting on the document’s DOCTYPE, xsi attributes, 
    or xml-model PIs, pre- and/or post-fix.</p:documentation>
  
  <p:input port="schema">
    <p:documentation>An expanded NVDL schema that associates Schematron validations with namespace URIs. 
      Alternatively, an assembled Schematron schema.</p:documentation>
  </p:input>
  <p:input port="source" primary="true">
    <p:documentation>Zip Manifest or other XML file for which Schematron checks exist. 
      Since a manifest will be processed before XML files in an archive, fixes that apply to the manifest 
      will be carried out first. 
      Each fixed XML file may optionally be rendered by sbf:render. Since these XML renderings receive 
      the updated (fixed) manifest and contents ports after the manifest fixes, all fixes to the contents,
      for example image conversions, should run as XProc fixes on the manifest (possibly enriched with image
      resolution, colorspace etc. info), not on the individual content items.
    </p:documentation>
  </p:input>
  <p:input port="contents" sequence="true">
    <p:documentation>If the input to the invoking validation pipeline was a zip, this port has its contents
    with base-uri document properties that match c:entry/@href in the manifest.</p:documentation>
  </p:input>
  <p:input port="archive-data-uri-map" content-types="application/json">
    <p:documentation>Will be initially empty when processing an archive manifest. After the fixes are applied
      to the archive manifest and the contents, archive-data-uri-map will be computed from the fixed manifest
      and contents. This map document will then be passed to the recursive sbf:schematron-for-namespace invocations
      on the XML files so that their rendering pipelines can use the data URIs. 
    </p:documentation>
    <p:inline content-type="application/json" expand-text="false">{}</p:inline>
  </p:input>
  
  <p:output port="result" primary="true" pipe="result@validate-if-schematron-exists-for-namespace">
    <p:documentation>The updated zip manifest or XML file that appeared on the source port. Updated:
    after fixes have been applied.</p:documentation>
  </p:output>
  <p:output port="result-contents" sequence="true" pipe="result-contents@process-contents"/>
  <p:output port="report" sequence="true" 
    pipe="report@validate-if-schematron-exists-for-namespace report@process-contents"/>
  <p:output port="rendering" sequence="true"
    pipe="rendering@validate-if-schematron-exists-for-namespace rendering@process-contents"/>
  
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
    <p:documentation>Validate, fix and re-validate zip manifest, XML zip content file, or standalone XML input.</p:documentation>
    <p:when test="/c:result = '0'">
      <p:documentation>No Schematron for namespace. Return a c:ok document on the report port 
        and the source port unchanged on the result port.</p:documentation>
      <p:output port="report">
        <p:inline><c:ok reason="no-schematron-for-namespace"/></p:inline>
      </p:output>
      <p:output port="result-contents" pipe="contents@schematron-for-namespace" sequence="true"/>
      <p:output port="result-archive-data-uri-map" pipe="archive-data-uri-map@schematron-for-namespace"
                content-types="application/json"/>
      <p:output port="result" primary="true"/>
      <p:identity>
        <p:with-input pipe="source@schematron-for-namespace"/>
      </p:identity>
    </p:when>
    <p:otherwise>
      <p:output port="report" pipe="result@add-doc-uri-to-reports"/>
      <p:output port="result" primary="true" pipe="result@remove-srcpath-in-fixed-doc"/>
      <p:output port="result-contents" pipe="result-contents@apply-fixes" sequence="true"/>
      <p:output port="result-archive-data-uri-map" pipe="result@conditionally-compute-archive-data-uri-map" 
                content-types="application/json"/>
      <p:output port="rendering" pipe="result@render" sequence="true" content-types="any"/>
      <sbf:add-srcpaths name="add-srcpaths">
        <p:with-input pipe="source@schematron-for-namespace"/>
      </sbf:add-srcpaths>
      <p:variable name="base-uri" as="xs:string?" select="p:urify(p:document-property(., 'base-uri'))"/>
      <p:variable name="params" as="map(*)*" pipe="params@schematron-from-nvdl-or-standalone" 
        select="collection()" collection="true"/>
      <p:variable name="consolidated-params" as="map(*)*" 
        select="map:merge((map{xs:QName('allow-foreign'): 'true'}, $params), map{'duplicates': 'combine'})"/>
      <tr:oxy-validate-with-schematron name="validate-with-schematron" 
        p:message="Schematron validation base URI: {$base-uri}, top-level element name: {/*/name()}">
        <p:with-option name="parameters" select="$consolidated-params"/>
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

      <sbf:apply-fixes name="apply-fixes">
        <p:with-input port="source" pipe="result@add-srcpaths"/>
        <p:with-input port="contents" pipe="contents@schematron-for-namespace"/>
      </sbf:apply-fixes>
      
      <tr:oxy-validate-with-schematron name="validate-with-schematron_pass2">
        <p:with-option name="parameters" select="$consolidated-params"/>
        <p:with-input port="schema" pipe="result@schematron-from-nvdl-or-standalone"/>
      </tr:oxy-validate-with-schematron>
      <p:identity name="svrlpass2-into-focus"><p:with-input pipe="report@validate-with-schematron_pass2"/></p:identity>
      <p:set-properties name="set-svrl-base-uri_pass2">
        <p:with-option name="properties" select="map{xs:QName('base-uri'): ($base-uri || '.fixed.val')}"/>
      </p:set-properties>
      <tr:store-debug name="store-svrl_pass2" active="{$debug}" base-uri="{$debug-dir-uri}"
        pipeline-step="schematron_pass2/{$base-uri => replace('^.+/', '')}.fixed.svrl"/>
      
      <p:wrap-sequence name="wrap-reports" wrapper="sbf:single-doc-reports">
        <p:with-input pipe="result@set-svrl-base-uri result@set-svrl-base-uri_pass2"/>
      </p:wrap-sequence>
      
      <p:add-attribute attribute-name="doc-uri" attribute-value="{$base-uri}" name="add-doc-uri-to-reports"/>
      
      <p:identity name="fixed-doc-into-focus"><p:with-input pipe="result@apply-fixes"/></p:identity>
      <p:delete match="@srcpath" name="remove-srcpath-in-fixed-doc"/>

      <p:choose name="conditionally-compute-archive-data-uri-map">
        <p:when test="exists(/c:archive)">
          <p:output port="result" content-types="application/json"/>
          <p:identity name="fixed-contents-into-focus"><p:with-input pipe="result-contents@apply-fixes"/></p:identity>
          <tr:archive-data-uri-map name="archive-data-uri-map">
            <p:with-input port="manifest" pipe="result@remove-srcpath-in-fixed-doc"></p:with-input>
          </tr:archive-data-uri-map>
        </p:when>
        <p:otherwise>
          <p:output port="result" content-types="application/json"/>
          <p:identity><p:with-input pipe="archive-data-uri-map@schematron-for-namespace"/></p:identity>
        </p:otherwise>
      </p:choose>

      <p:identity name="fixed-doc-into-focus-again"><p:with-input pipe="result@remove-srcpath-in-fixed-doc"/></p:identity>
      
      <sbf:render name="render">
        <p:with-input port="schema" pipe="schema@schematron-for-namespace">
          <p:documentation>The rendering pipeline (XProc) may be specified in
            /nvdl:rules/nvdl:namespace/sbf:rendering-pipeline/@href</p:documentation>
        </p:with-input>
        <p:with-input port="archive-data-uri-map" pipe="result@conditionally-compute-archive-data-uri-map"/>
      </sbf:render>
    </p:otherwise>
  </p:choose>
  
  <p:choose name="process-contents">
    <p:documentation>If the previous validation/fix/validation steps operated on a zip manifest, process
      each of the XML content files in the zip with this sbf:schematron-for-namespace step recursively.</p:documentation>
    <p:when test="$namespace-uri = 'http://www.w3.org/ns/xproc-step' and $local-name = 'archive'">
      <p:output port="report" sequence="true" pipe="report@process-xml-entries"/>
      <p:output port="result-contents" primary="true" sequence="true">
        <p:documentation>This result will become the new contents “stream” that will go into the output zip. Even if the
          files were renamed for the output zip, the base-uri property will stay the same. The renaming only occurs 
        in the c:entry/@name attribute of the archive manifest.</p:documentation>
      </p:output>
      <p:output port="rendering" sequence="true" content-types="any" pipe="rendering@process-xml-entries"/>
      <p:variable name="normalized-xml-uris" as="xs:string*" 
        select="/c:archive/c:entry[@namespace-uri]/@href ! p:urify(.)"/>
      
      <p:for-each name="process-xml-entries">
        <p:with-input pipe="result-contents@validate-if-schematron-exists-for-namespace"/>
        <p:output port="report" pipe="report@is-xml" sequence="true"/>
        <p:output port="result" primary="true"/>
        <p:output port="rendering" sequence="true" content-types="any" pipe="rendering@is-xml"/>
        <p:variable name="base-uri" as="xs:string" select="p:urify(p:document-property(., 'base-uri'))"/>
        <p:variable name="is-xml" as="xs:boolean" select="$base-uri = $normalized-xml-uris"/>
        <p:choose name="is-xml">
          <p:when test="$is-xml">
            <p:output port="report" pipe="report@recursive-schematron-for-namespace"/>
            <p:output port="result" primary="true"/>
            <p:output port="rendering" sequence="true" content-types="any" pipe="rendering@recursive-schematron-for-namespace"/>
            <p:identity name="current-into-focus-again"><p:with-input pipe="current@process-xml-entries"/></p:identity>
            <sbf:schematron-for-namespace name="recursive-schematron-for-namespace">
              <p:with-input port="schema" pipe="schema@schematron-for-namespace"/>
              <p:with-input port="contents"><p:empty/>
                <!--<p:documentation>The complete (fixed) contents port needs to be passed to each step because an XML
                rendering pipeline may ask for data URIs for embedded images and the like.</p:documentation>-->
              </p:with-input>
              <p:with-input port="archive-data-uri-map" 
                pipe="result-archive-data-uri-map@validate-if-schematron-exists-for-namespace"/>
              <p:with-option name="debug" select="$debug"/>
              <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
            </sbf:schematron-for-namespace>
          </p:when>
          <p:otherwise>
            <p:output port="result" primary="true"/>
            <p:output port="report" sequence="true">
              <p:empty/>
            </p:output>
            <p:output port="rendering" sequence="true">
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
