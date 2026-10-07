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
  name="render" type="sbf:render">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:documentation>Will try to load the rendering pipeline that is specified in
    /nvdl:rules/nvdl:namespace/sbf:rendering-pipeline/@href and apply it to the fixed XML.</p:documentation>
  
  <p:input port="schema">
    <p:documentation>An expanded NVDL schema that associates Schematron validations with namespace URIs
      and sbf:rendering-pipeline instructions. If different rendering pipelines should apply according to
      the top level element, sbf:rendering-pipeline may have an attribute local-names that contains a space-separated
      list of top-level elements (only their local names).
      Parameters can be supplied as a c:param-set child of sbf:rendering-pipeline. The parameters will be supplied
      to the pipeline as a map in an option named 'parameters'.
      If the schema isn’t NVDL but merely a Schematron schema, no rendering pipeline can be specified 
      declaratively.</p:documentation>
  </p:input>
  <p:input port="source" primary="true">
    <p:documentation>Batch-fixed XML file.</p:documentation>
  </p:input>
  <p:input port="archive-data-uri-map" content-types="application/json">
    <p:inline content-type="application/json" expand-text="false">{}</p:inline>
  </p:input>
  
  <p:output port="result" primary="true" sequence="true" content-types="any" pipe="result@conditionally-render">
    <p:documentation>Zero, one or more renderings. For example, the pipeline can create a PDF and an HTML rendering
    of the input.</p:documentation>
  </p:output>
  
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:variable name="namespace-uri" as="xs:string" select="namespace-uri(/*) => string()"/>
  <p:variable name="local-name" as="xs:string" select="local-name(/*)"/>
  
  <p:identity name="schema-into-focus">
    <p:with-input pipe="schema@render"/>
  </p:identity>
  
  <p:variable name="pipeline-spec" as="element(sbf:pipeline)?"
    select="/nvdl:rules/nvdl:namespace[@ns = $namespace-uri]
              /sbf:rendering-pipeline[empty(@local-names)
                                      or tokenize(@local-names) = $local-name]"/>

  <p:choose name="pipeline-from-nvdl">
    <p:when test="exists(/nvdl:rules)">
      <p:output port="result" sequence="true" primary="true"/>
      <p:output port="params" sequence="true" pipe="params@load-pipeline" content-types="application/json"/>
      <p:try name="load-pipeline">
        <p:output port="result" sequence="true" primary="true"/>
        <p:output port="params" sequence="true" pipe="result@param-sets" content-types="application/json"/>
        <p:for-each name="param-sets">
          <p:with-input select="$pipeline-spec/c:param-set"/>
          <p:output port="result" content-types="application/json"/>
          <p:cast-content-type content-type="application/json"/>
        </p:for-each>
        <p:load href="{$pipeline-spec/@href}"/>
        <p:catch>
          <p:output port="result" sequence="true" primary="true"/>
          <p:output port="params" sequence="true" content-types="application/json"><p:empty/></p:output>
          <p:identity><p:with-input><p:empty/></p:with-input></p:identity>
        </p:catch>
      </p:try>
    </p:when>
    <p:otherwise>
      <p:output port="result" sequence="true" primary="true"/>
      <p:output port="params" sequence="true"><p:empty/></p:output>
      <p:identity><p:with-input><p:empty/></p:with-input></p:identity>
    </p:otherwise>
  </p:choose>

  <p:variable name="params" as="map(*)*" pipe="params@pipeline-from-nvdl" 
    select="collection()" collection="true"/>
    
  <p:variable name="parameters" as="map(*)?" select="if (exists($params)) 
                                                     then map:merge($params, map{'duplicates': 'combine'})
                                                     else ()"/>
  
  <p:identity message="render.xpl parameters: {serialize($parameters, map{'method': 'json'})}" name="pipeline-into-focus">
    <p:with-input pipe="result@pipeline-from-nvdl"/>
  </p:identity>
  
  <p:choose name="conditionally-render">
    <p:when test="exists($parameters)">
      <p:output port="result" primary="true"/>
      <p:run name="run-rendering-pipeline">
        <p:with-input pipe="result@pipeline-into-focus"/>
        <p:run-input port="source" pipe="source@render" primary="true"/>
        <p:run-input port="archive-data-uri-map" pipe="archive-data-uri-map@render"/>
        <p:run-option name="parameters" as="map(*)?" select="$parameters"/>
        <p:output port="result" primary="true" sequence="true" content-types="any"/>
      </p:run>
    </p:when>
    <p:otherwise>
      <p:output port="result" primary="true" sequence="true"/>
      <p:identity><p:with-input><p:empty/></p:with-input></p:identity>
    </p:otherwise>
  </p:choose>
</p:declare-step>
