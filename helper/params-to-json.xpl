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
  name="params-to-json" type="sbf:params-to-json">
  
  <p:option name="key-type" as="xs:string" select="'QName'"/>

  <p:input port="source" sequence="true" select="/*/*:param">
    <!--<p:inline><c:param-set>
        <c:param name="foo" value="bar"/>
        <c:param name="baz" value="bar"/>
    </c:param-set>
      <sbf:param-set>
        <sbf:param name="foos" value="bars"/>
        <sbf:param name="bazs" value="bars"/>
      </sbf:param-set>
    </p:inline>-->
  </p:input>

  <p:output port="result" sequence="true" content-types="application/json"/>
  
  <p:for-each>
    <p:output port="result" primary="true" content-types="application/json"/>
    <p:identity>
      <p:with-input select="map:entry(if ($key-type = 'QName') then xs:QName(/*:param/@name) else string(/*:param/@name), 
                                      string(/*:param/@value))"/>
    </p:identity>
  </p:for-each>
  
  <!--  <p:variable name="merged" as="map(*)*" select="map:merge(collection())" collection="true"/>
  
  <p:identity message="FFFF {serialize($merged, map{'method':'json'})} {map:keys($merged)[1] ! . instance of xs:QName}"/>-->
</p:declare-step>
