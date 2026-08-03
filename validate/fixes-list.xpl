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
  name="fixes-list" type="sbf:fixes-list">

  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:input port="svrl" primary="true">
    <p:documentation>Schematron validation result, possibly with sbf:xsl-fix and/or sbf:xproc-fix elements.</p:documentation>
  </p:input>
  
  <p:input port="schema">
    <p:documentation>The (sbf-extends-assembled) Schematron that was used for generating the SVRL. 
    We need the complete Schematron, too, because the fixes demanded in the SVRL may have other fixes as prerequisites that
    are not in the SVRL.</p:documentation>
  </p:input>
  
  <p:output port="result" primary="true">
    <p:documentation>An sbf:fixes-list document with the sbf:xsl-fixes and/or sbf:xproc-fixes in execution order, taking
      prerequisite fixes into account.</p:documentation> 
  </p:output>

  <p:option name="debug-dir-uri" select="''"/>
  <p:option name="debug" select="'no'"/>
  
  <p:variable name="base-uri" select="p:document-property(., 'base-uri') => replace('^\.val$', '')"/>
  
  <p:xslt name="create-fixes-list" template-name="main">
    <p:with-input port="stylesheet" href="fixes-list.xsl"/>
    <p:with-input port="source" pipe="svrl@fixes-list schema@fixes-list"/>
  </p:xslt>
  
  <tr:store-debug name="store-fixes-list" active="{$debug}" base-uri="{$debug-dir-uri}"
    pipeline-step="fixes-list/{$base-uri => replace('^.+/', '')}"/>
  
</p:declare-step>
