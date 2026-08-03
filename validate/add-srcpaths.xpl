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
  name="add-srcpaths" type="sbf:add-srcpaths">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:input port="source" primary="true">
    <p:documentation>Zip Manifest or other XML file</p:documentation>
  </p:input>
  
  <p:output port="result" primary="true"/>

  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:xslt name="xslt-add-srcpath">
    <p:with-input port="stylesheet">
      <p:inline expand-text="false">
        <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
          <xsl:mode on-no-match="shallow-copy"/>
          <xsl:template match="*">
            <xsl:copy>
              <xsl:attribute name="srcpath" select="path(.) => replace('/Q\{\}', '/')"/>
              <xsl:apply-templates select="@*, node()"/>
            </xsl:copy>
          </xsl:template>
        </xsl:stylesheet>  
      </p:inline>
    </p:with-input>
  </p:xslt>
  
  <tr:store-debug name="store-svrl" active="{$debug}" base-uri="{$debug-dir-uri}"
    pipeline-step="add-srcpaths/{p:document-property(., 'base-uri') => replace('^.+/', '')}"/>
  
</p:declare-step>
