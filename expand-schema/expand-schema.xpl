<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:nvdl="http://purl.oclc.org/dsdl/nvdl/ns/structure/1.0"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:tr="http://transpect.io"
  version="3.1" 
  name="expand-schema" type="sbf:expand-schema">
  
  <p:import href="http://transpect.io/sbf/assemble-schematron/assemble-schematron.xpl"/>
  
  <p:input port="source" primary="true">
    <p:documentation>A (simple) NVDL schema that associates Schematron validations with namespace URIs. 
      Alternatively, just a Schematron schema.
    If the base URI ends in [basename].compiled.[extension] (with [extension] being either nvdl or sch), 
    don’t try to expand the schema, just use it as provided.</p:documentation>
  </p:input>
  
  <p:output port="result" primary="true">
    <p:documentation>This output can be stored in a schema cache directory. If its name ends in 
      [basename].compiled.[extension] (with [extension] being either nvdl or sch), it can be passed to the schema
    port in order to accelerate processing. If the schema and its included components do not change, it 
    is recommended to call this sbf:expand-schema step in a separate call and to pass the compiled schema
    to the validation step.</p:documentation>
  </p:output>

  <p:documentation>
    Read, expand and optionally cache Schema (NVDL or Schematron)
       a. For NVDL, include assembled Schematron schemas referenced by validation/@schema below the validation elements.
       b. Assemble Schematron(s), either the primary input Schematron or each referenced Schematron. For the latter,
          the assembled Schematron will then be stored below validation.
       c. Optionally store the expanded schema 
  </p:documentation>

  <p:choose>
    <p:when test="contains(replace(base-uri(.), '^.+/', ''), '.compiled.')">
      <p:identity/>
    </p:when>
    <p:otherwise>
      <p:viewport match="nvdl:validate[@schema][empty(@schemaType) or ends-with(@schemaType, 'xml')]"
        name="get-schematron">
        <p:load href="{/nvdl:validate/@schema}" name="load-schematron"/>
        <p:choose message="NS: {namespace-uri(/*)}">
          <p:when test="namespace-uri(/*) = 'http://purl.oclc.org/dsdl/schematron'">
            <sbf:assemble-schematron name="assemble-schematron"/>
            <p:insert position="last-child">
              <p:with-input port="source" pipe="current@get-schematron"/>
              <p:with-input port="insertion" pipe="result@assemble-schematron"/>
            </p:insert>
          </p:when>
          <p:otherwise>
            <p:identity/>
          </p:otherwise>
        </p:choose>
      </p:viewport>    
    </p:otherwise>
  </p:choose>

</p:declare-step>
