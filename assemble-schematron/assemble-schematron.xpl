<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:sbf="http://transpect.io/schematron-batch-fix"
  xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
  xmlns:tr="http://transpect.io"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  type="sbf:assemble-schematron" name="assemble-schematron"
  version="3.1">
  <p:input port="source" primary="true"/>
  <p:input port="xslt">
    <p:document href="assemble-schematron.xsl"/>
  </p:input>
  <p:output port="result" primary="true"/>
  <p:xslt>
    <p:with-input port="stylesheet" pipe="xslt@assemble-schematron"/>
  </p:xslt>
</p:declare-step>