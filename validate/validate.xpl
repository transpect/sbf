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
  name="batch-val" type="sbf:batch-val">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  <p:import href="../find-files/enrich-archive-manifest.xpl"/>
  <p:import href="../expand-schema/expand-schema.xpl"/>
  <p:import href="schematron-for-namespace.xpl"/>
  
  <p:input port="schema">
    <p:documentation>A (simple) NVDL schema that associates Schematron validations with namespace URIs. 
      Alternatively, just a Schematron schema.</p:documentation>
  </p:input>
  <p:input port="source" content-types="xml application/zip" sequence="true" primary="true">
    <p:documentation>If we also want to be able to process directories, we should probably provide a way
    to supply the filesystem path or URI of an input file/directory?
    Then we can make the source port sequence="true" and use the input URI if no document is provided on
    the source port.
    Alternatively, a front-end pipeline could zip a directory and pass it to this step. An advantage of
    this zip-only interface is that XProc fixes can focus on operating on zips, rather than flexibly 
    dealing with zips and directories.
    We will only focus on zips for the time being, but they can already be passed as file system path or URI.
    Currently we don’t expect to deal with multiple inputs passed to this step. We will eventually do so. 
    </p:documentation>
  </p:input>
  <p:input port="svrl2html" href="svrl2html.xsl"/>
  
  <p:option name="input-uri" as="xs:string?" required="false">
    <p:documentation>Alternative way for specifying the file to be validated. Will only be used if there
    are zero documents on the 'source' port.</p:documentation>
  </p:option>

  <!--<p:output port="errors" sequence="true">
    <p:pipe port="result" step="insert-post-fix-svrl"/>
  </p:output>-->
  <!--<p:output port="shortreport" sequence="true">
    <p:pipe port="result" step="html2shortreport"/>
  </p:output>-->

  <p:output port="result" primary="true" pipe="result@input-files">
    <p:documentation>Always a Zip? Currently, it is a repackaged zip or the fixed XML. But we also want
    a zip that contains the fixed input plus the reports (and maybe also the original input).</p:documentation>
  </p:output>
  <p:output port="report" sequence="true" pipe="report@input-files"/>
  <p:output port="result-contents" sequence="true" pipe="result-contents@input-files"/>
  <p:output port="htmlreport" pipe="result@svrl2html" 
    serialization="map{'method': 'xhtml', 'use-character-maps': map {'&gt;': '>'}}"/>
  <p:output port="rendering" pipe="rendering@input-files" sequence="true" 
    serialization="map{'method': 'xhtml', 'use-character-maps': map {'&gt;': '>'}}"/>
  
  <p:option name="keep-srcpath" select="'pi_changed'">
    <p:documentation>Whether to keep srcpath attributes in the result. Possible values: 'no' (remove them),
    'pi_always': keep them as processing instructions, 'pi_changed': only keep them if the current path differs,
    'yes': keep them</p:documentation>
  </p:option>
  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:documentation>
    0. Read and expand Schema (NVDL or Schematron). For speed-up, an already expanded schema can be passed to the step.
       a. Enrich NVDL schema with assembled versions of Schematron files referred by validation/@schema's.
          (Schematron assembly means: Expansion of the sbf:extends instructions.)
       b. If input is just Schematron, assemble it. 
    1. Load input (by URI or input port): 
       a. For Zip input, get/enrich manifest (→ result) and contents from source
          Enrichment: 
          aa. Determine namespace URI for XML files
          bb. Include XML files below c:entry so that the manifest Schematron can, for instance, compare
              c:entry hrefs with graphic filenames 
              (Optionally, perform DTD, XSD, or xml-model based non-Schematron schema validation when or after loading
               the files and record c:errors document below the same c:entry; c:errors may also be created when an XML
               document isn’t well-formed.)
       b. For XML input, use source (→ result)
    2. look up DRP's namespace (xproc-step for zip/directory processing or other for XML input (where input can also be an 
       XMLized representation of image properties, for instance – then XProc fixes can convert these images from TIFF to
       PNG, for instance).
       This item 2. is encapsulated in sbf:schematron-for-namespace
       2.1 select Schematron from NVDL according to this NS
           If there is no NVDL, just Schematron, on the schema port, use the Schematron. 
           Both standalone and embedded-in-NVDL Schematron are expected to be sbf:extends-expanded.
       2.2 If ∃ Schematron:
           a. add srcpath to the source document (except for archive manifests?)
           b. validate doc, set SVRL base URI so that it can be associated with validated file (append '.val' to URI),
              send SVRL to report port, send doc to result port, send potential zip content stream to content port
       2.3 Collect all fixes from the SVRLs, group them by SVRL base URI
           This item 2.3 is encapsulated as sbf:apply-fixes
           2.3.1 Create fix execution plan for each document URI (calculated from SVRL URI),
                 observing dependencies among fixes (but only for the same document)
           2.3.2 Apply fixes to the documents, each fix operates on the previous fix's output.
                 XProc fixes operate on manifest doc + contents
       2.4 Validate each doc again, collect SVRL
           Check whether an error that had been reported for a given srcpath (or href, for manifest documents) 
           is still being reported
     3. If source is archive manifest: 
       a. viewport all c:entries with NS (if there are none, the process is finished and returns the input unchanged): 
       b. apply 2. to this input (do we support archives in archives? not yet)
    4. Create HTML and brief report
  </p:documentation>

  <sbf:expand-schema name="expand-schema">
    <p:with-input pipe="schema@batch-val"/>
  </sbf:expand-schema>

  <p:identity>
    <p:with-input pipe="source@batch-val"/>
  </p:identity>

  <p:count name="count-source"/>
  
  <p:choose>
    <p:when test="xs:integer(/c:result) = 0 and $input-uri">
      <p:load href="{$input-uri}"/>
    </p:when>
    <p:when test="xs:integer(/c:result) = 0 and not($input-uri)">
      <p:error code="sbf:no-input">
        <p:with-input port="source">
          <message>Please provide either input on the source port or by specifying the input-uri option.</message>
        </p:with-input>
      </p:error>
    </p:when>
    <p:otherwise>
      <p:identity>
        <p:with-input pipe="source@batch-val"/>
      </p:identity>
    </p:otherwise>
    <p:documentation>need to deal with $input-uri that points to a directory (for example, create a zip from it)</p:documentation>
  </p:choose>
    
  <p:for-each name="input-files">
    <p:output port="result" primary="true"/>
    <p:output port="report" pipe="report@schematron-for-namespace" sequence="true"/>
    <p:output port="result-contents" pipe="result-contents@schematron-for-namespace" sequence="true"/>
    <p:output port="rendering" pipe="rendering@schematron-for-namespace" sequence="true"/>
    
    <p:variable name="is-zip" select="p:document-property(., 'content-type') = 'application/zip'" as="xs:boolean"/>

    <p:choose name="zip-or-xml">
      <p:when test="$is-zip">
        <p:output port="result" primary="true"/>
        <p:output port="contents" sequence="true" pipe="contents@enrich-archive-manifest"/>
        <sbf:enrich-archive-manifest name="enrich-archive-manifest"/>
      </p:when>
      <p:otherwise>
        <p:output port="result" primary="true"/>
        <p:output port="contents" sequence="true">
          <p:empty/>
        </p:output>
        <p:identity/>
      </p:otherwise>
    </p:choose>
    
    <sbf:schematron-for-namespace name="schematron-for-namespace">
      <p:with-input port="schema" pipe="result@expand-schema"/>
      <p:with-input port="source" pipe="result@zip-or-xml"/>
      <p:with-input port="contents" pipe="contents@zip-or-xml"/>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
    </sbf:schematron-for-namespace>
    
    <p:choose name="zip-or-xml2">
      <p:when test="$is-zip">
        <p:output port="result" primary="true"/>
        <p:delete match="@name-old | @cx:* | c:entry/*" name="delete-unsupported-manifest-attributes"/>
        <tr:store-debug pipeline-step="repackage-manifest" active="{$debug}" base-uri="{$debug-dir-uri}"/>
        <p:archive name="repackage">
          <p:with-input port="source" pipe="result-contents@schematron-for-namespace"/>
          <p:with-input port="manifest" pipe="result@delete-unsupported-manifest-attributes"/>
        </p:archive>
      </p:when>
      <p:otherwise>
        <p:output port="result" primary="true"/>
        <p:output port="contents" sequence="true">
          <p:empty/>
        </p:output>
        <p:identity/>
      </p:otherwise>
    </p:choose>
  </p:for-each>

  <p:identity name="reports-into-focus"><p:with-input pipe="report@input-files"/></p:identity>
  <tr:store-debug pipeline-step="reports" active="{$debug}" base-uri="{$debug-dir-uri}"/>

  <p:xslt name="svrl2html" template-name="main">
    <p:with-input port="stylesheet" pipe="svrl2html@batch-val"/>
  </p:xslt>
</p:declare-step>
