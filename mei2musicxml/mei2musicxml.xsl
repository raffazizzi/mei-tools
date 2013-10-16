<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
  xmlns:mei="http://www.music-encoding.org/ns/mei" exclude-result-prefixes="mei"
  xmlns:saxon="http://saxon.sf.net/" extension-element-prefixes="saxon">
  <xsl:output doctype-system="http://www.musicxml.org/dtds/timewise.dtd"
    doctype-public="-//Recordare//DTD MusicXML 2.0 Partwise//EN" method="xml" indent="yes"
    encoding="UTF-8" omit-xml-declaration="no" standalone="no"/>
  <xsl:strip-space elements="*"/>

  <!-- parameters -->
  <!-- PARAM:ppqDefault
      This parameter defines the number of pulses per quarter note when it's
      not defined in the input file. Suggested values are:
      960
      768
      96
  -->
  <xsl:param name="ppqDefault" select="960"/>

  <!-- PARAM:reQuantize
      This parameter controls whether @dur.ges values in the file are used or discarded.
      A value of 'false()' uses @dur.ges values in the file, if they exist. A value of 
      'true()' ignores any @dur.ges values in the file and calculates new values based 
      on the value of the ppqDefault parameter.
  -->
  <xsl:param name="reQuantize" select="false()"/>

  <!-- global variables -->
  <xsl:variable name="nl">
    <xsl:text>&#xa;</xsl:text>
  </xsl:variable>
  <xsl:variable name="progName">
    <xsl:text>mei2musicxml.xsl</xsl:text>
  </xsl:variable>
  <xsl:variable name="progVersion">
    <xsl:text>v. 0.2</xsl:text>
  </xsl:variable>

  <!-- 'Match' templates -->
  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="mei:mei">
        <!-- $stage1 will hold MusicXML-like MEI markup; that is, (mostly)
        MEI elements organized by part -->
        <xsl:variable name="stage1">
          <xsl:apply-templates select="mei:mei"/>
        </xsl:variable>
        <xsl:copy-of select="$stage1"/>
        <!--<xsl:apply-templates select="$stage1/*" mode="stage2"/>-->
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="errorMessage">The source file is not an MEI file!</xsl:variable>
        <xsl:message terminate="yes">
          <xsl:value-of select="normalize-space($errorMessage)"/>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mei:mei">
    <score-partwise>
      <xsl:apply-templates select="mei:meiHead"/>
      <xsl:apply-templates select="mei:music/mei:body/mei:mdiv/mei:score/mei:scoreDef"
        mode="defaults"/>
      <xsl:apply-templates select="mei:music/mei:body/mei:mdiv/mei:score/mei:scoreDef"
        mode="credits"/>
      <xsl:value-of select="$nl"/>
      <part-list>
        <xsl:apply-templates
          select="mei:music/mei:body/mei:mdiv/mei:score/mei:scoreDef/mei:staffGrp" mode="partList"/>
      </part-list>
      <xsl:apply-templates select="mei:music/mei:body/mei:mdiv/mei:score//mei:measure" mode="stage1"
      />
    </score-partwise>
  </xsl:template>

  <xsl:template match="mei:anchoredText">
    <credit>
      <xsl:attribute name="page">
        <xsl:choose>
          <xsl:when test="ancestor::mei:pgHead or ancestor::mei:pgFoot">
            <xsl:value-of select="1"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:pgHead2 or ancestor::mei:pgFoot2">
            <xsl:value-of select="2"/>
          </xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@n">
        <credit-type>
          <xsl:value-of select="replace(@n, '_', '&#32;')"/>
        </credit-type>
      </xsl:if>
      <xsl:for-each-group select="mei:*" group-ending-with="mei:lb">
        <credit-words>
          <xsl:if test="position() = 1">
            <xsl:if test="ancestor::mei:anchoredText/@x">
              <xsl:attribute name="default-x">
                <xsl:value-of select="format-number(ancestor::mei:anchoredText/@x * 5,
                  '###0.####')"/>
              </xsl:attribute>
            </xsl:if>
            <xsl:if test="ancestor::mei:anchoredText/@y">
              <xsl:attribute name="default-y">
                <xsl:value-of select="format-number(ancestor::mei:anchoredText/@y * 5,
                  '###0.####')"/>
              </xsl:attribute>
            </xsl:if>
          </xsl:if>
          <xsl:call-template name="rendition"/>
          <xsl:variable name="creditText">
            <xsl:for-each select="current-group()">
              <xsl:apply-templates select="." mode="stage1"/>
              <xsl:if test="position() != last()">
                <xsl:text>&#32;</xsl:text>
              </xsl:if>
            </xsl:for-each>
          </xsl:variable>
          <xsl:value-of select="$creditText"/>
        </credit-words>
      </xsl:for-each-group>
    </credit>
  </xsl:template>

  <xsl:template match="mei:arpeg | mei:beamSpan | mei:breath | mei:fermata | mei:hairpin |
    mei:harpPedal | mei:octave | mei:pedal | mei:reh | mei:slur | mei:tie | mei:tupletSpan |
    mei:bend | mei:dir | mei:dynam | mei:harm | mei:gliss | mei:phrase| mei:tempo | mei:mordent |
    mei:trill | mei:turn" mode="stage1">
    <xsl:copy>
      <!-- Copy all attributes but @staff. -->
      <xsl:copy-of select="@*[not(local-name() = 'staff')]"/>
      <xsl:variable name="thisStaff">
        <xsl:choose>
          <!-- use @staff when provided -->
          <xsl:when test="@staff">
            <xsl:value-of select="@staff"/>
          </xsl:when>
          <!-- use staff assignment of starting event -->
          <xsl:when test="@startid">
            <xsl:variable name="startEventID">
              <xsl:value-of select="substring(@startid, 2)"/>
            </xsl:variable>
            <xsl:choose>
              <!-- starting event has @staff -->
              <xsl:when test="preceding::mei:*[@xml:id=$startEventID and @staff]">
                <xsl:value-of select="preceding::mei:*[@xml:id=$startEventID]/@staff"/>
              </xsl:when>
              <!-- starting event has a staff element ancestor -->
              <xsl:otherwise>
                <xsl:value-of
                  select="preceding::mei:*[@xml:id=$startEventID]/ancestor::mei:staff/@n"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
        </xsl:choose>
      </xsl:variable>
      <xsl:variable name="partID">
        <xsl:choose>
          <!-- use the xml:id of preceding staffGrp that has staff definition child for the current staff -->
          <xsl:when test="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]][1]/@xml:id"/>
          </xsl:when>
          <!-- use the xml:id of preceding staffGrp that has staff definition descendant for the current staff -->
          <xsl:when test="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]][1]/@xml:id"
            />
          </xsl:when>
          <!-- use the xml:id of preceding staffDef for the current staff -->
          <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @xml:id]">
            <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
              @xml:id][1]/@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- construct a part ID -->
            <xsl:text>P_</xsl:text>
            <xsl:choose>
              <xsl:when
                test="count(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef)=1">
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[1])"
                />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1])"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:attribute name="partID">
        <xsl:value-of select="$partID"/>
      </xsl:attribute>
      <!-- staff assignment in MEI; that is, staff counted from top to bottom of score -->
      <xsl:attribute name="meiStaff">
        <xsl:value-of select="$thisStaff"/>
      </xsl:attribute>
      <!-- staff assignment in MusicXML; that is, where the numbering of staves starts over with each part -->
      <xsl:attribute name="partStaff">
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id and
            mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:for-each select="preceding::mei:staffGrp[@xml:id and
              mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[@n=$thisStaff]">
              <xsl:value-of select="count(preceding-sibling::mei:staffDef) + 1"/>
            </xsl:for-each>
          </xsl:when>
          <xsl:when
            test="preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:value-of select="1"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$thisStaff"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates mode="stage1"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mei:availability">
    <xsl:if test="normalize-space(mei:useRestrict) != ''">
      <rights>
        <xsl:value-of select="mei:useRestrict"/>
      </rights>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mei:beam | mei:chord | mei:tuplet" mode="stage1">
    <xsl:variable name="thisStaff">
      <xsl:value-of select="ancestor::mei:staff/@n"/>
    </xsl:variable>
    <xsl:variable name="ppq">
      <xsl:choose>
        <!-- preceding staff definition for this staff has ppq value -->
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and @ppq][1]/@ppq"/>
        </xsl:when>
        <!-- preceding score definition has ppq value -->
        <xsl:when test="preceding::mei:scoreDef[@ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:scoreDef[@ppq][1]/@ppq"/>
        </xsl:when>
        <!-- preceding event on this staff has an undotted quarter note duration and gestural duration -->
        <xsl:when test="preceding::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          not(@dots) and @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(preceding::mei:*[ancestor::mei:staff[@n=$thisStaff] and
            @dur='4' and not(@dots) and @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <!-- following event on this staff has an undotted quarter note duration and gestural duration -->
        <xsl:when test="following::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          not(@dots) and @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(following::mei:*[ancestor::mei:staff[@n=$thisStaff] and
            @dur='4' and not(@dots) and @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$ppqDefault"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="meterCount">
      <xsl:choose>
        <!-- preceding staff definition for this staff sets the meter count -->
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.count]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.count][1]/@meter.count"/>
        </xsl:when>
        <!-- preceding score definition sets the meter count -->
        <xsl:when test="preceding::mei:scoreDef[@meter.count]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.count][1]/@meter.count"/>
        </xsl:when>
        <!-- assume 4-beat measure -->
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="meterUnit">
      <xsl:choose>
        <!-- preceding staff definition for this staff sets the meter unit -->
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.unit]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <!-- preceding score definition sets the meter unit -->
        <xsl:when test="preceding::mei:scoreDef[@meter.unit]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <!-- assume a quarter note meter unit -->
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="measureDuration">
      <xsl:call-template name="measureDuration">
        <xsl:with-param name="ppq" select="$ppq"/>
        <xsl:with-param name="meterCount" select="$meterCount"/>
        <xsl:with-param name="meterUnit" select="$meterUnit"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:copy>
      <!-- copy all attributes except @staff and @dur.ges; these will be supplied later -->
      <xsl:copy-of select="@*[not(local-name() = 'staff') and not(name()='dur.ges')]"/>
      <xsl:attribute name="measureDuration">
        <xsl:value-of select="$measureDuration"/>
      </xsl:attribute>
      <xsl:variable name="partID">
        <xsl:choose>
          <!-- use the xml:id of preceding staffGrp that has staff definition child for the current staff -->
          <xsl:when test="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]][1]/@xml:id"/>
          </xsl:when>
          <!-- use the xml:id of preceding staffGrp that has staff definition descendant for the current staff -->
          <xsl:when test="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]][1]/@xml:id"
            />
          </xsl:when>
          <!-- use the xml:id of preceding staffDef for the current staff -->
          <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @xml:id]">
            <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
              @xml:id][1]/@xml:id"/>
          </xsl:when>
          <!-- construct a part ID -->
          <xsl:otherwise>
            <!-- construct a part ID -->
            <xsl:text>P_</xsl:text>
            <xsl:choose>
              <xsl:when
                test="count(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef)=1">
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[1])"
                />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1])"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:attribute name="partID">
        <xsl:value-of select="$partID"/>
      </xsl:attribute>
      <!-- staff assignment in MEI; that is, staff counted from top to bottom of score -->
      <xsl:attribute name="meiStaff">
        <xsl:value-of select="ancestor::mei:staff/@n"/>
      </xsl:attribute>
      <!-- staff assignment in MusicXML; that is, where the numbering of staves starts over with each part -->
      <xsl:attribute name="partStaff">
        <xsl:variable name="thisStaff">
          <xsl:choose>
            <xsl:when test="not(@staff)">
              <xsl:value-of select="$thisStaff"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@staff"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:choose>
          <!-- use position of this staff in a preceding staff group -->
          <xsl:when test="preceding::mei:staffGrp[@xml:id and
            mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:for-each select="preceding::mei:staffGrp[@xml:id and
              mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[@n=$thisStaff]">
              <xsl:value-of select="count(preceding-sibling::mei:staffDef) + 1"/>
            </xsl:for-each>
          </xsl:when>
          <!-- this staff is the only one in a group -->
          <xsl:when
            test="preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:value-of select="1"/>
          </xsl:when>
          <!-- default to the MEI staff value -->
          <xsl:otherwise>
            <xsl:value-of select="$thisStaff"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <!-- At this point, voice = layer assigned in MEI -->
      <xsl:attribute name="voice">
        <xsl:value-of select="ancestor::mei:layer/@n"/>
      </xsl:attribute>
      <xsl:if test="local-name()='chord'">
        <xsl:attribute name="dur.ges">
          <xsl:choose>
            <!-- if chord has a gestural duration and requantization isn't called for, use @dur.ges value -->
            <xsl:when test="@dur.ges and not($reQuantize)">
              <xsl:value-of select="replace(@dur.ges, '[^\d]+', '')"/>
            </xsl:when>
            <!-- event is a grace note/chord; gestural duration = 0 -->
            <xsl:when test="@grace">
              <xsl:value-of select="0"/>
            </xsl:when>
            <!-- calculate gestural duration based on written duration -->
            <xsl:otherwise>
              <xsl:call-template name="gesturalDurationFromWrittenDuration">
                <xsl:with-param name="writtenDur">
                  <xsl:choose>
                    <!-- chord has a written duration -->
                    <xsl:when test="@dur">
                      <xsl:value-of select="@dur"/>
                    </xsl:when>
                    <!-- preceding note, rest, or chord has a written duration -->
                    <xsl:when test="preceding-sibling::mei:*[(local-name()='note' or
                      local-name()='chord' or local-name()='rest') and @dur]">
                      <xsl:value-of select="preceding-sibling::mei:*[(local-name()='note'
                        or local-name()='chord' or local-name()='rest') and
                        @dur][1]/@dur"/>
                    </xsl:when>
                    <!-- following note, rest, or chord has a written duration -->
                    <xsl:when test="following-sibling::mei:*[(local-name()='note' or
                      local-name()='chord' or local-name()='rest') and @dur]">
                      <xsl:value-of select="following-sibling::mei:*[(local-name()='note'
                        or local-name()='chord' or local-name()='rest') and
                        @dur][1]/@dur"/>
                    </xsl:when>
                    <!-- when all else fails, assume a quarter note written duration -->
                    <xsl:otherwise>
                      <xsl:value-of select="4"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="dots">
                  <xsl:choose>
                    <!-- chord's written duration is dotted -->
                    <xsl:when test="@dots">
                      <xsl:value-of select="@dots"/>
                    </xsl:when>
                    <!-- no dots -->
                    <xsl:otherwise>
                      <xsl:value-of select="0"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="ppq">
                  <xsl:value-of select="$ppq"/>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </xsl:if>
      <xsl:copy-of select="comment()"/>
      <xsl:apply-templates select="mei:*" mode="stage1"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mei:clef" mode="stage1">
    <xsl:variable name="thisStaff">
      <xsl:value-of select="ancestor::mei:staff/@n"/>
    </xsl:variable>
    <xsl:variable name="ppq">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and @ppq][1]/@ppq"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:scoreDef[@ppq][1]/@ppq"/>
        </xsl:when>
        <xsl:when test="preceding::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          not(@dots) and @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(preceding::mei:*[@dur='4' and not(@dots) and
            @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <xsl:when test="following::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          not(@dots) and @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(following::mei:*[ancestor::mei:staff[@n=$thisStaff] and
            @dur='4' and not(@dots) and @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$ppqDefault"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="meterCount">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.count]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.count][1]/@meter.count"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@meter.count]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.count][1]/@meter.count"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="meterUnit">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.unit]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@meter.unit]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:copy>
      <xsl:copy-of select="@*[not(local-name() = 'staff') and not(name()='dur.ges')]"/>
      <xsl:variable name="partID">
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]][1]/@xml:id"/>
          </xsl:when>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]][1]/@xml:id"
            />
          </xsl:when>
          <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @xml:id]">
            <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
              @xml:id][1]/@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- construct a part ID -->
            <xsl:text>P_</xsl:text>
            <xsl:choose>
              <xsl:when
                test="count(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef)=1">
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[1])"
                />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1])"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:attribute name="partID">
        <xsl:value-of select="$partID"/>
      </xsl:attribute>
      <!-- staff assignment in MEI; that is, staff counted from top to bottom of score -->
      <xsl:attribute name="meiStaff">
        <xsl:value-of select="ancestor::mei:staff/@n"/>
      </xsl:attribute>
      <!-- staff assignment in MusicXML; that is, where the numbering of staves starts over with each part -->
      <xsl:attribute name="partStaff">
        <xsl:variable name="thisStaff">
          <xsl:choose>
            <xsl:when test="not(@staff)">
              <xsl:value-of select="$thisStaff"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@staff"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id and
            mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:for-each select="preceding::mei:staffGrp[@xml:id and
              mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[@n=$thisStaff]">
              <xsl:value-of select="count(preceding-sibling::mei:staffDef) + 1"/>
            </xsl:for-each>
          </xsl:when>
          <xsl:when
            test="preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:value-of select="1"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$thisStaff"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <!-- At this point, voice = layer assigned in MEI -->
      <xsl:attribute name="voice">
        <xsl:value-of select="ancestor::mei:layer/@n"/>
      </xsl:attribute>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mei:fileDesc" mode="source">
    <xsl:for-each select="mei:titleStmt">
      <xsl:variable name="creators">
        <xsl:for-each select="mei:respStmt/*[@role='creator' or @role='composer' or
          @role='librettist' or @role='lyricist' or @role='arranger']">
          <xsl:value-of select="replace(., '\.+', '.')"/>
          <xsl:if test="position() != last()">
            <xsl:text>,&#32;</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="encoders">
        <xsl:for-each select="mei:respStmt/*[@role='encoder']">
          <xsl:value-of select="replace(., '\.+', '.')"/>
          <xsl:if test="position() != last()">
            <xsl:text>,&#32;</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="title">
        <xsl:for-each select="mei:title">
          <xsl:value-of select="."/>
          <xsl:if test="position() != last()">
            <xsl:text>,&#32;</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="publisher">
        <xsl:for-each select="../mei:pubStmt/mei:respStmt[1]/mei:*">
          <xsl:value-of select="replace(., '\.+', '.')"/>
          <xsl:if test="position() != last()">
            <xsl:text>,&#32;</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pubPlace">
        <xsl:for-each select="../mei:pubStmt/mei:address[1]/mei:addrLine">
          <xsl:value-of select="replace(., '\.+', '.')"/>
          <xsl:if test="position() != last()">
            <xsl:text>,&#32;</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pubDate">
        <xsl:value-of select="../mei:pubStmt/mei:date[1]"/>
      </xsl:variable>
      <xsl:if test="normalize-space($creators) != ''">
        <xsl:value-of select="normalize-space($creators)"/>
        <xsl:if test="not(matches(normalize-space($creators), '\.$'))">
          <xsl:text>.</xsl:text>
        </xsl:if>
        <xsl:if test="normalize-space($title) != ''">
          <xsl:text>&#32;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:if test="normalize-space($title) != ''">
        <xsl:value-of select="normalize-space($title)"/>
        <xsl:if test="not(matches(normalize-space($title), '\.$'))">
          <xsl:text>.</xsl:text>
        </xsl:if>
        <xsl:if test="normalize-space($encoders) != ''">
          <xsl:text>&#32;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:if test="normalize-space($encoders) != ''">
        <xsl:text>Encoded by&#32;</xsl:text>
        <xsl:value-of select="normalize-space($encoders)"/>
        <xsl:if test="not(matches(normalize-space($encoders), '\.$'))">
          <xsl:text>.</xsl:text>
        </xsl:if>
        <xsl:if test="normalize-space($publisher) != ''">
          <xsl:text>&#32;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:if test="normalize-space($publisher) != ''">
        <xsl:value-of select="normalize-space($publisher)"/>
        <xsl:if test="normalize-space($publisher) != ''">
          <xsl:text>:&#32;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:if test="normalize-space($pubPlace) != ''">
        <xsl:value-of select="normalize-space($pubPlace)"/>
        <xsl:if test="normalize-space($pubPlace) != ''">
          <xsl:text>,&#32;</xsl:text>
        </xsl:if>
      </xsl:if>
      <xsl:if test="normalize-space($pubDate) != ''">
        <xsl:value-of select="$pubDate"/>
        <xsl:if test="not(matches(normalize-space($pubDate), '\.$'))">
          <xsl:text>.</xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="mei:meiHead">
    <xsl:choose>
      <xsl:when test="mei:workDesc/mei:work">
        <xsl:apply-templates select="mei:workDesc/mei:work"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="mei:fileDesc/mei:sourceDesc/mei:source[1]"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mei:identifier" mode="workTitle">
    <!-- Do nothing! Exclude identifier from title content -->
  </xsl:template>

  <xsl:template match="mei:instrDef" mode="partList">
    <score-instrument>
      <xsl:attribute name="id">
        <xsl:choose>
          <!-- use existing xml:id -->
          <xsl:when test="@xml:id">
            <xsl:value-of select="@xml:id"/>
          </xsl:when>
          <!-- construction instrument id -->
          <xsl:otherwise>
            <xsl:text>I_</xsl:text>
            <xsl:value-of select="generate-id()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <instrument-name>
        <xsl:value-of select="replace(@midi.instrname, '_', '&#32;')"/>
      </instrument-name>
    </score-instrument>
    <midi-instrument>
      <xsl:attribute name="id">
        <xsl:choose>
          <xsl:when test="@xml:id">
            <xsl:value-of select="@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>I_</xsl:text>
            <xsl:value-of select="generate-id()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@midi.channel">
        <midi-channel>
          <xsl:value-of select="@midi.channel"/>
        </midi-channel>
      </xsl:if>
      <xsl:if test="@midi.instrnum">
        <midi-program>
          <!-- MusicXML uses 1-based program numbers -->
          <xsl:value-of select="@midi.instrnum + 1"/>
        </midi-program>
      </xsl:if>
      <volume>
        <!-- MusicXML uses scaling factor instead of actual MIDI value -->
        <xsl:value-of select="round((@midi.volume * 100) div 127)"/>
      </volume>
      <pan>
        <!-- Placement within stereo sound field (left=0, right=127) -->
        <xsl:choose>
          <xsl:when test="@midi.pan = 63 or @midi.pan = 64">
            <xsl:value-of select="0"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="round(-90 + ((180 div 127) * @midi.pan))"/>
          </xsl:otherwise>
        </xsl:choose>
      </pan>
    </midi-instrument>
  </xsl:template>

  <xsl:template match="mei:lb" mode="stage1">
    <xsl:text>&#xA;</xsl:text>
  </xsl:template>

  <xsl:template match="mei:measure" mode="stage1">
    <measure>
      <!-- DEBUG: -->
      <xsl:copy-of select="@*"/>

      <xsl:variable name="thisMeasure">
        <xsl:value-of select="@xml:id"/>
      </xsl:variable>

      <xsl:variable name="sb">
        <xsl:choose>
          <!-- system break between this measure and the previous one -->
          <xsl:when
            test="preceding-sibling::mei:sb[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]">
            <xsl:copy-of
              select="preceding-sibling::mei:sb[preceding-sibling::mei:measure[following-sibling::mei:measure[@xml:id=$thisMeasure]]][1]"
            />
          </xsl:when>
          <!-- system break between this measure and the previous one -->
          <xsl:when test="local-name(preceding-sibling::*[1]) = 'sb'">
            <xsl:copy-of select="preceding-sibling::mei:sb[1]"/>
          </xsl:when>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="localScoreDef">
        <xsl:choose>
          <!-- first measure -->
          <xsl:when test="count(preceding::mei:measure[not(ancestor::mei:incip)])=0">
            <!-- copy score-level score definition (minus page header/footer info) to first measure -->
            <scoreDef xmlns="http://www.music-encoding.org/ns/mei"
              xmlns:xlink="http://www.w3.org/1999/xlink">
              <xsl:attribute name="defaultScoreDef">defaultScoreDef</xsl:attribute>
              <xsl:choose>
                <!-- reQuantize -->
                <xsl:when test="$reQuantize">
                  <!-- copy all attributes but @ppq, add new @ppq on scoreDef -->
                  <xsl:copy-of
                    select="//mei:music//mei:score/mei:scoreDef/@*[not(local-name()='ppq')]"/>
                  <xsl:attribute name="ppq">
                    <xsl:value-of select="$ppqDefault"/>
                  </xsl:attribute>
                  <!-- remove @ppq on descendants -->
                  <xsl:apply-templates
                    select="//mei:music//mei:score/mei:scoreDef/mei:*[not(starts-with(local-name(),
                    'pg'))]" mode="dropPPQ"/>
                </xsl:when>
                <xsl:otherwise>
                  <!-- copy attributes and descendants unchanged -->
                  <xsl:copy-of select="//mei:music//mei:score/mei:scoreDef/@*"/>
                  <xsl:copy-of
                    select="//mei:music//mei:score/mei:scoreDef/mei:*[not(starts-with(local-name(),
                    'pg'))]"/>
                </xsl:otherwise>
              </xsl:choose>
            </scoreDef>
            <!-- process any scoreDef or staffDef elements that precede the first measure -->
            <!-- look for preceding score definition -->
            <xsl:if test="preceding-sibling::mei:scoreDef">
              <scoreDef xmlns="http://www.music-encoding.org/ns/mei"
                xmlns:xlink="http://www.w3.org/1999/xlink">
                <xsl:choose>
                  <!-- reQuantize -->
                  <xsl:when test="$reQuantize">
                    <!-- copy all attributes but @ppq -->
                    <xsl:copy-of
                      select="preceding-sibling::mei:scoreDef/@*[not(local-name()='ppq')]"/>
                    <!-- remove @ppq on descendants -->
                    <xsl:apply-templates
                      select="preceding-sibling::mei:scoreDef/mei:*[not(starts-with(local-name(),
                      'pg'))]" mode="dropPPQ"/>
                  </xsl:when>
                  <!-- copy attributes and descendants unchanged -->
                  <xsl:otherwise>
                    <xsl:copy-of select="preceding-sibling::mei:scoreDef/@*"/>
                    <xsl:copy-of
                      select="preceding-sibling::mei:scoreDef/mei:*[not(starts-with(local-name(),
                      'pg'))]"/>
                  </xsl:otherwise>
                </xsl:choose>
              </scoreDef>
            </xsl:if>
            <!-- look for preceding staff definitions -->
            <xsl:if test="preceding-sibling::mei:staffDef">
              <xsl:for-each select="preceding-sibling::mei:staffDef">
                <staffDef xmlns="http://www.music-encoding.org/ns/mei"
                  xmlns:xlink="http://www.w3.org/1999/xlink">
                  <xsl:choose>
                    <!-- reQuantize -->
                    <xsl:when test="$reQuantize">
                      <!-- copy all attributes but @ppq -->
                      <xsl:copy-of select="@*[not(local-name()='ppq')]"/>
                      <xsl:attribute name="ppq">
                        <xsl:value-of select="$ppqDefault"/>
                      </xsl:attribute>
                    </xsl:when>
                    <!-- copy attributes and descendants unchanged -->
                    <xsl:otherwise>
                      <xsl:copy-of select="@*"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </staffDef>
              </xsl:for-each>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <!-- measures other than the first -->
            <!-- look for score definition between this measure and the previous one -->
            <xsl:if
              test="preceding-sibling::mei:scoreDef[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]">
              <scoreDef xmlns="http://www.music-encoding.org/ns/mei"
                xmlns:xlink="http://www.w3.org/1999/xlink">
                <xsl:choose>
                  <!-- reQuantize -->
                  <xsl:when test="$reQuantize">
                    <!-- copy all attributes but @ppq -->
                    <xsl:copy-of
                      select="preceding-sibling::mei:scoreDef[preceding-sibling::mei:measure[following-sibling::mei:measure[@xml:id=$thisMeasure]]][1]/@*[not(local-name()='ppq')]"/>
                    <!-- remove @ppq on descendants -->
                    <xsl:apply-templates
                      select="preceding-sibling::mei:scoreDef[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]/mei:*[not(starts-with(local-name(),
                      'pg'))]" mode="dropPPQ"/>
                  </xsl:when>
                  <!-- copy attributes and descendants unchanged -->
                  <xsl:otherwise>
                    <xsl:copy-of
                      select="preceding-sibling::mei:scoreDef[preceding-sibling::mei:measure[following-sibling::mei:measure[@xml:id=$thisMeasure]]][1]/@*"/>
                    <xsl:copy-of
                      select="preceding-sibling::mei:scoreDef[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]/mei:*[not(starts-with(local-name(),
                      'pg'))]"/>
                  </xsl:otherwise>
                </xsl:choose>
              </scoreDef>
            </xsl:if>
            <!-- look for staff definition(s) between this measure and the previous one -->
            <xsl:if
              test="preceding-sibling::mei:staffDef[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]">
              <xsl:for-each
                select="preceding-sibling::mei:staffDef[preceding-sibling::mei:measure[following-sibling::mei:measure[1][@xml:id=$thisMeasure]]]">
                <staffDef xmlns="http://www.music-encoding.org/ns/mei"
                  xmlns:xlink="http://www.w3.org/1999/xlink">
                  <xsl:choose>
                    <!-- reQuantize -->
                    <xsl:when test="$reQuantize">
                      <!-- copy all attributes but @ppq -->
                      <xsl:copy-of select="@*[not(local-name()='ppq')]"/>
                    </xsl:when>
                    <!-- copy attributes and descendants unchanged -->
                    <xsl:otherwise>
                      <xsl:copy-of select="@*"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </staffDef>
              </xsl:for-each>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- $measureContent collects stage 1 results -->
      <xsl:variable name="measureContent">
        <events>
          <xsl:apply-templates select="mei:staff/mei:layer/* | mei:staff/comment() |
            mei:staff/mei:layer/comment()" mode="stage1"/>
        </events>
        <controlevents>
          <xsl:apply-templates select="*[not(local-name()='staff')] | comment()" mode="stage1"/>
        </controlevents>
      </xsl:variable>

      <!-- DEBUG: -->
      <!--<xsl:copy-of select="$measureContent"/>-->

      <!-- Group events by part and voice -->
      <xsl:variable name="measureContent2">
        <xsl:for-each-group select="$measureContent/events/*" group-by="@partID">
          <part id="{@partID}">
            <xsl:for-each-group select="current-group()" group-by="@voice">
              <xsl:for-each-group select="current-group()" group-by="@meiStaff">
                <voice>
                  <xsl:copy-of select="current-group()"/>
                </voice>
              </xsl:for-each-group>
            </xsl:for-each-group>
          </part>
        </xsl:for-each-group>
        <!-- carry along control events for now -->
        <xsl:copy-of select="$measureContent/controlevents"/>
      </xsl:variable>

      <!-- DEBUG: -->
      <!--<xsl:copy-of select="$measureContent2"/>-->

      <!-- Number voices -->
      <xsl:variable name="measureContent3">
        <xsl:for-each select="$measureContent2/part">
          <part>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="voice">
              <xsl:sort select="*[@meiStaff][1]/@meiStaff"/>
              <xsl:sort select="*[@meiStaff][1]/@voice"/>
              <voice>
                <xsl:for-each select="*">
                  <xsl:copy>
                    <xsl:copy-of select="@*[not(local-name()='voice')]"/>
                    <xsl:attribute name="voice">
                      <xsl:for-each select="ancestor::voice">
                        <xsl:value-of select="count(preceding-sibling::voice) + 1"/>
                      </xsl:for-each>
                    </xsl:attribute>
                    <xsl:copy-of select="* | comment() | text()"/>
                  </xsl:copy>
                </xsl:for-each>
              </voice>
            </xsl:for-each>
          </part>
        </xsl:for-each>
        <!-- carry along control events for now -->
        <xsl:copy-of select="$measureContent2/controlevents"/>
      </xsl:variable>

      <!-- DEBUG: -->
      <!--<xsl:copy-of select="$measureContent3"/>-->

      <!-- Add tstamp.ges to voice chldren; replace voice elements with <backup> delimiter -->
      <xsl:variable name="measureContent4">
        <xsl:for-each select="$measureContent3/part">
          <part>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="voice">            
              <xsl:variable name="voiceContent">
                <xsl:copy-of select="*"/>
              </xsl:variable>
              <xsl:apply-templates select="$voiceContent/*" mode="addTstamp.ges"/>
              <xsl:if test="position() != last()">
                <backup>
                  <duration>
                    <xsl:variable name="backupDuration">
                      <xsl:value-of select="sum(mei:*//@dur.ges)"/>
                    </xsl:variable>
                    <xsl:choose>
                      <xsl:when test="$backupDuration &gt; 0">
                        <!-- backup value = the sum of the preceding events in this voice -->
                        <xsl:value-of select="$backupDuration"/>
                      </xsl:when>
                      <xsl:otherwise>
                        <!-- backup to beginning of measure -->
                        <xsl:value-of select="mei:*[@measureDuration][1]/@measureDuration"/>
                      </xsl:otherwise>
                    </xsl:choose>
                  </duration>
                </backup>
              </xsl:if>
            </xsl:for-each>
          </part>
        </xsl:for-each>
        <!-- carry along control events for now -->
        <xsl:copy-of select="$measureContent3/controlevents"/>
      </xsl:variable>

      <!-- DEBUG: -->
      <!--<xsl:copy-of select="$measureContent4"/>-->

      <!-- re-wrap sorted events in <events>; copy control events into appropriate part -->
      <xsl:variable name="measureContent5">
        <xsl:for-each select="$measureContent4/part">
          <part>
            <xsl:copy-of select="@*"/>
            <events>
              <xsl:copy-of select="*"/>
            </events>
            <xsl:variable name="partID">
              <xsl:value-of select="@id"/>
            </xsl:variable>
            <controlevents>
              <xsl:copy-of select="$measureContent4/controlevents/*[@partID=$partID] |
                $measureContent4/controlevents/comment()"/>
            </controlevents>
          </part>
        </xsl:for-each>
      </xsl:variable>

      <!-- DEBUG: -->
      <!--<xsl:copy-of select="$measureContent5"/>-->

      <!-- if there are any system breaks or score definitions between this measure 
        and the previous one, copy them into each part -->
      <xsl:variable name="measureContent6">
        <xsl:for-each select="$measureContent5/part">
          <part>
            <xsl:copy-of select="@*"/>

            <xsl:if test="$sb/*">
              <xsl:copy-of select="$sb"/>
            </xsl:if>

            <xsl:if test="$localScoreDef/*">
              <!-- if it's not empty, $localScoreDef will contain the default 
              definition and any local modifications for the first measure, but
              only local modifications in subsequent measures -->
              <xsl:copy-of select="$localScoreDef"/>
            </xsl:if>

            <xsl:copy-of select="events"/>
            <!-- drop empty controlevents container -->
            <xsl:if test="controlevents/node()">
              <xsl:copy-of select="controlevents"/>
            </xsl:if>

          </part>
        </xsl:for-each>
      </xsl:variable>

      <!-- copy modified measure content into measure element -->
      <xsl:copy-of select="$measureContent6"/>

    </measure>
  </xsl:template>

  <xsl:template match="mei:note | mei:rest | mei:chord | mei:space | mei:mRest | mei:mSpace"
    mode="addTstamp.ges">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <!-- if not already present, add @tstamp.ges -->
      <xsl:if test="not(@tstamp.ges) and local-name(..) != 'chord'">
        <xsl:attribute name="tstamp.ges">
          <xsl:value-of select="sum(preceding::mei:*[@dur.ges]/@dur.ges)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates mode="addTstamp.ges"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mei:note | mei:rest | mei:space | mei:mRest | mei:mSpace" mode="stage1">
    <xsl:variable name="thisStaff">
      <xsl:value-of select="ancestor::mei:staff/@n"/>
    </xsl:variable>
    <xsl:variable name="ppq">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and @ppq][1]/@ppq"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@ppq] and not($reQuantize)">
          <xsl:value-of select="preceding::mei:scoreDef[@ppq][1]/@ppq"/>
        </xsl:when>
        <xsl:when test="preceding::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          not(@dots) and @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(preceding::mei:*[ancestor::mei:staff[@n=$thisStaff] and
            @dur='4' and not(@dots) and @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <xsl:when test="following::mei:*[ancestor::mei:staff[@n=$thisStaff] and @dur='4' and
          @dur.ges] and not($reQuantize)">
          <xsl:value-of select="replace(following::mei:*[ancestor::mei:staff[@n=$thisStaff] and
            @dur='4' and not(@dots) and @dur.ges][1]/@dur.ges, '[^\d]+', '')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$ppqDefault"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="meterCount">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.count]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.count][1]/@meter.count"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@meter.count]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.count][1]/@meter.count"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="meterUnit">
      <xsl:choose>
        <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @meter.unit]">
          <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
            @meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <xsl:when test="preceding::mei:scoreDef[@meter.unit]">
          <xsl:value-of select="preceding::mei:scoreDef[@meter.unit][1]/@meter.unit"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="4"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="measureDuration">
      <xsl:call-template name="measureDuration">
        <xsl:with-param name="ppq" select="$ppq"/>
        <xsl:with-param name="meterCount" select="$meterCount"/>
        <xsl:with-param name="meterUnit" select="$meterUnit"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:copy>
      <xsl:copy-of select="@*[not(local-name() = 'staff') and not(name()='dur.ges')]"/>
      <xsl:attribute name="measureDuration">
        <xsl:value-of select="$measureDuration"/>
      </xsl:attribute>
      <xsl:variable name="partID">
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]][1]/@xml:id"/>
          </xsl:when>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]][1]/@xml:id"
            />
          </xsl:when>
          <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @xml:id]">
            <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
              @xml:id][1]/@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- construct a part ID -->
            <xsl:text>P_</xsl:text>
            <xsl:choose>
              <xsl:when
                test="count(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef)=1">
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[1])"
                />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1])"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- part ID -->
      <xsl:attribute name="partID">
        <xsl:value-of select="$partID"/>
      </xsl:attribute>
      <!-- staff assignment in MEI; that is, staff counted from top to bottom of score -->
      <xsl:attribute name="meiStaff">
        <xsl:value-of select="ancestor::mei:staff/@n"/>
      </xsl:attribute>
      <!-- staff assignment in MusicXML; that is, where the numbering of staves starts over with each part -->
      <xsl:attribute name="partStaff">
        <xsl:variable name="thisStaff">
          <xsl:choose>
            <xsl:when test="not(@staff)">
              <xsl:value-of select="$thisStaff"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@staff"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id and
            mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:for-each select="preceding::mei:staffGrp[@xml:id and
              mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[@n=$thisStaff]">
              <xsl:value-of select="count(preceding-sibling::mei:staffDef) + 1"/>
            </xsl:for-each>
          </xsl:when>
          <xsl:when
            test="preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:value-of select="1"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$thisStaff"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <!-- At this point, voice = layer assigned in MEI -->
      <xsl:attribute name="voice">
        <xsl:value-of select="ancestor::mei:layer/@n"/>
      </xsl:attribute>
      <xsl:if test="local-name(..) != 'chord'">
        <xsl:attribute name="dur.ges">
          <xsl:choose>
            <xsl:when test="@dur.ges and not($reQuantize)">
              <xsl:value-of select="replace(@dur.ges, '[^\d]+', '')"/>
            </xsl:when>
            <!-- event is a grace note/chord; gestural duration = 0 -->
            <xsl:when test="@grace">
              <xsl:value-of select="0"/>
            </xsl:when>
            <!-- event is a measure rest or space -->
            <xsl:when test="local-name()='mRest' or local-name()='mSpace'">
              <xsl:choose>
                <!-- calculate gestural duration based on written duration -->
                <xsl:when test="@dur">
                  <xsl:call-template name="gesturalDurationFromWrittenDuration">
                    <xsl:with-param name="writtenDur">
                      <xsl:value-of select="@dur"/>
                    </xsl:with-param>
                    <xsl:with-param name="dots">
                      <xsl:choose>
                        <xsl:when test="@dots">
                          <xsl:value-of select="@dots"/>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:value-of select="0"/>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="ppq">
                      <xsl:value-of select="$ppq"/>
                    </xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <!-- no written duration; use measure duration based on ppq and meter -->
                <xsl:otherwise>
                  <xsl:value-of select="$measureDuration"/>
                </xsl:otherwise>
                <!-- could use sum of gestural durations of events on other layer of 
                    this or some other staff -->
              </xsl:choose>
            </xsl:when>
            <!-- event is neither grace, measure rest nor measure space -->
            <xsl:otherwise>
              <!-- calculate gestural duration based on written duration -->
              <xsl:call-template name="gesturalDurationFromWrittenDuration">
                <xsl:with-param name="writtenDur">
                  <xsl:choose>
                    <!-- event has a written duration -->
                    <xsl:when test="@dur">
                      <xsl:value-of select="@dur"/>
                    </xsl:when>
                    <!-- ancestor, such as chord, has a written duration -->
                    <xsl:when test="ancestor::mei:*[@dur]">
                      <xsl:value-of select="ancestor::mei:*[@dur][1]/@dur"/>
                    </xsl:when>
                    <!-- preceding note, rest, or chord has a written duration -->
                    <xsl:when test="preceding-sibling::mei:*[(local-name()='note' or
                      local-name()='chord' or local-name()='rest') and @dur]">
                      <xsl:value-of select="preceding-sibling::mei:*[(local-name()='note'
                        or local-name()='chord' or local-name()='rest') and
                        @dur][1]/@dur"/>
                    </xsl:when>
                    <!-- following note, rest, or chord has a written duration -->
                    <xsl:when test="following-sibling::mei:*[(local-name()='note' or
                      local-name()='chord' or local-name()='rest') and @dur]">
                      <xsl:value-of select="following-sibling::mei:*[(local-name()='note'
                        or local-name()='chord' or local-name()='rest') and
                        @dur][1]/@dur"/>
                    </xsl:when>
                    <!-- when all else fails, assume a quarter note written duration -->
                    <xsl:otherwise>
                      <xsl:value-of select="4"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="dots">
                  <xsl:choose>
                    <xsl:when test="@dots">
                      <xsl:value-of select="@dots"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="0"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="ppq">
                  <xsl:value-of select="$ppq"/>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </xsl:if>
      <xsl:copy-of select="comment()"/>
      <xsl:apply-templates select="mei:*" mode="stage1"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="mei:pgHead | mei:pgFoot | mei:pgHead2 | mei:pgFoot2">
    <xsl:choose>
      <xsl:when test="mei:anchoredText">
        <xsl:apply-templates select="mei:anchoredText"/>
      </xsl:when>
      <xsl:otherwise>
        <credit>
          <xsl:attribute name="page">
            <xsl:choose>
              <xsl:when test="ancestor-or-self::mei:pgHead or ancestor-or-self::mei:pgFoot">
                <xsl:value-of select="1"/>
              </xsl:when>
              <xsl:when test="ancestor-or-self::mei:pgHead2 or ancestor-or-self::mei:pgFoot2">
                <xsl:value-of select="2"/>
              </xsl:when>
            </xsl:choose>
          </xsl:attribute>
          <xsl:choose>
            <!-- pgHead, etc. contains only rend and lb elements -->
            <xsl:when test="(mei:rend or mei:lb) and count(mei:rend) + count(mei:lb) = count(mei:*)">
              <xsl:for-each select="mei:rend">
                <credit-words>
                  <xsl:call-template name="rendition"/>
                  <xsl:apply-templates mode="stage1"/>
                </credit-words>
              </xsl:for-each>
            </xsl:when>
            <xsl:when test="mei:table and count(mei:table) = count(mei:*)">
              <!-- pgHead, etc. contains a table -->
              <xsl:for-each select="descendant::mei:td">
                <credit-words>
                  <xsl:copy-of select="mei:rend[1]/@*"/>
                  <xsl:apply-templates mode="stage1"/>
                </credit-words>
              </xsl:for-each>
            </xsl:when>
            <!-- pgHead, etc. has mixed content -->
            <xsl:when test="text()">
              <credit-words>
                <xsl:apply-templates mode="stage1"/>
              </credit-words>
            </xsl:when>
            <!-- pgHead, etc. contains MEI elements other than rend, lb, or table -->
            <xsl:otherwise>
              <xsl:for-each select="mei:*[not(local-name()='lb')]">
                <xsl:choose>
                  <!-- subordinate element contains only rend and lb elements -->
                  <xsl:when test="(mei:rend or mei:lb) and count(mei:rend) + count(mei:lb) =
                    count(mei:*)">
                    <xsl:for-each select="mei:rend">
                      <credit-words>
                        <xsl:call-template name="rendition"/>
                        <xsl:apply-templates mode="stage1"/>
                      </credit-words>
                    </xsl:for-each>
                  </xsl:when>
                  <!-- subordinate element has mixed content -->
                  <xsl:otherwise>
                    <credit-words>
                      <xsl:apply-templates mode="stage1"/>
                    </credit-words>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
        </credit>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mei:rend" mode="stage1">
    <xsl:apply-templates mode="stage1"/>
  </xsl:template>

  <xsl:template match="mei:scoreDef" mode="credits">
    <xsl:apply-templates select="mei:pgHead | mei:pgFoot | mei:pgHead2 | mei:pgFoot2"/>
  </xsl:template>

  <xsl:template match="mei:scoreDef" mode="defaults">
    <xsl:if test="@vu.height | @page.height | @page.width | @page.leftmar | @page.rightmar |
      @page.topmar | @page.botmar | @system.leftmar | @system.rightmar | @system.topmar |
      @spacing.system | @spacing.staff | @music.name | @text.name | @lyric.name">
      <defaults>
        <xsl:if test="@vu.height">
          <scaling>
            <millimeters>
              <xsl:value-of select="number(replace(@vu.height, '[a-z]+$', '')) * 8"/>
            </millimeters>
            <tenths>40</tenths>
          </scaling>
        </xsl:if>
        <xsl:if test="@page.height | @page.width | @page.leftmar | @page.rightmar | @page.topmar |
          @page.botmar">
          <page-layout>
            <page-height>
              <xsl:value-of select="format-number(number(replace(@page.height, '[a-z]+$', '')) *
                5, '###0.####')"/>
            </page-height>
            <page-width>
              <xsl:value-of select="format-number(number(replace(@page.width, '[a-z]+$', '')) * 5,
                '###0.####')"/>
            </page-width>
            <page-margins type="both">
              <left-margin>
                <xsl:choose>
                  <xsl:when test="replace(@page.leftmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@page.leftmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@page.leftmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@page.leftmar, '[a-z]+$',
                      '')) * 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </left-margin>
              <right-margin>
                <xsl:choose>
                  <xsl:when test="replace(@page.rightmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@page.rightmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@page.rightmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@page.rightmar, '[a-z]+$',
                      '')) * 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </right-margin>
              <top-margin>
                <xsl:choose>
                  <xsl:when test="replace(@page.topmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@page.topmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@page.topmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@page.topmar, '[a-z]+$', ''))
                      * 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </top-margin>
              <bottom-margin>
                <xsl:choose>
                  <xsl:when test="replace(@page.botmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@page.botmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@page.botmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@page.botmar, '[a-z]+$', ''))
                      * 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </bottom-margin>
            </page-margins>
          </page-layout>
        </xsl:if>
        <xsl:if test="@system.leftmar | @system.rightmar | @system.topmar | @spacing.system">
          <system-layout>
            <system-margins>
              <left-margin>
                <xsl:choose>
                  <xsl:when test="replace(@system.leftmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@system.leftmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@system.leftmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@system.leftmar, '[a-z]+$',
                      ''))* 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </left-margin>
              <right-margin>
                <xsl:choose>
                  <xsl:when test="replace(@system.rightmar, '[a-z]+$', '') = '0'">
                    <xsl:value-of select="@system.rightmar"/>
                  </xsl:when>
                  <xsl:when test="number(replace(@system.rightmar, '[a-z]+$', ''))">
                    <xsl:value-of select="format-number(number(replace(@system.rightmar, '[a-z]+$',
                      '')) * 5, '###0.####')"/>
                  </xsl:when>
                </xsl:choose>
              </right-margin>
            </system-margins>
            <system-distance>
              <xsl:choose>
                <xsl:when test="replace(@spacing.system, '[a-z]+$', '') = '0'">
                  <xsl:value-of select="@spacing.system"/>
                </xsl:when>
                <xsl:when test="number(replace(@spacing.system, '[a-z]+$', ''))">
                  <xsl:value-of select="format-number(number(replace(@spacing.system, '[a-z]+$',
                    '')) * 5, '###0.####')"/>
                </xsl:when>
              </xsl:choose>
            </system-distance>
            <top-system-distance>
              <xsl:choose>
                <xsl:when test="replace(@system.topmar, '[a-z]+$', '') = '0'">
                  <xsl:value-of select="@system.topmar"/>
                </xsl:when>
                <xsl:when test="number(replace(@system.topmar, '[a-z]+$', ''))">
                  <xsl:value-of select="format-number(number(replace(@system.topmar, '[a-z]+$', ''))
                    * 5, '###0.####')"/>
                </xsl:when>
              </xsl:choose>
            </top-system-distance>
          </system-layout>
        </xsl:if>
        <xsl:if test="@spacing.staff">
          <staff-layout>
            <staff-distance>
              <xsl:choose>
                <xsl:when test="replace(@spacing.staff, '[a-z]+$', '') = '0'">
                  <xsl:value-of select="@spacing.staff"/>
                </xsl:when>
                <xsl:when test="number(replace(@spacing.staff, '[a-z]+$', ''))">
                  <xsl:value-of select="format-number(number(replace(@spacing.staff, '[a-z]+$', ''))
                    * 5, '###0.####')"/>
                </xsl:when>
              </xsl:choose>
            </staff-distance>
          </staff-layout>
        </xsl:if>
        <xsl:if test="@music.name | @text.name | @lyric.name">
          <music-font font-family="{@music.name}">
            <xsl:if test="@music.size">
              <xsl:attribute name="font-size">
                <xsl:value-of select="@music.size"/>
              </xsl:attribute>
            </xsl:if>
          </music-font>
        </xsl:if>
        <xsl:if test="@text.name">
          <word-font font-family="{@text.name}">
            <xsl:if test="@text.size">
              <xsl:attribute name="font-size">
                <xsl:value-of select="@text.size"/>
              </xsl:attribute>
            </xsl:if>
          </word-font>
        </xsl:if>
        <xsl:if test="@lyric.name">
          <lyric-font font-family="{@lyric.name}">
            <xsl:if test="@lyric.size">
              <xsl:attribute name="font-size">
                <xsl:value-of select="@lyric.size"/>
              </xsl:attribute>
            </xsl:if>
          </lyric-font>
        </xsl:if>
      </defaults>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mei:staff/comment() | mei:layer/comment()" mode="stage1">
    <!-- comments within staff or layer become comment elements so that they can be assigned
    to a part and staff -->
    <comment>
      <xsl:variable name="thisStaff">
        <xsl:value-of select="ancestor::mei:staff/@n"/>
      </xsl:variable>
      <xsl:variable name="partID">
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][mei:staffDef[@n=$thisStaff]][1]/@xml:id"/>
          </xsl:when>
          <xsl:when test="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]]">
            <xsl:value-of
              select="preceding::mei:staffGrp[@xml:id][descendant::mei:staffDef[@n=$thisStaff]][1]/@xml:id"
            />
          </xsl:when>
          <xsl:when test="preceding::mei:staffDef[@n=$thisStaff and @xml:id]">
            <xsl:value-of select="preceding::mei:staffDef[@n=$thisStaff and
              @xml:id][1]/@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- construct a part ID -->
            <xsl:text>P_</xsl:text>
            <xsl:choose>
              <xsl:when
                test="count(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef)=1">
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[1])"
                />
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of
                  select="generate-id(preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]][1])"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- part ID -->
      <xsl:attribute name="partID">
        <xsl:value-of select="$partID"/>
      </xsl:attribute>
      <!-- staff assignment in MEI; that is, staff counted from top to bottom of score -->
      <xsl:attribute name="meiStaff">
        <xsl:value-of select="ancestor::mei:staff/@n"/>
      </xsl:attribute>
      <!-- staff assignment in MusicXML; that is, where the numbering of staves starts over with each part -->
      <xsl:attribute name="partStaff">
        <xsl:choose>
          <xsl:when test="preceding::mei:staffGrp[@xml:id and
            mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:for-each select="preceding::mei:staffGrp[@xml:id and
              mei:staffDef[@n=$thisStaff]][1]/mei:staffDef[@n=$thisStaff]">
              <xsl:value-of select="count(preceding-sibling::mei:staffDef) + 1"/>
            </xsl:for-each>
          </xsl:when>
          <xsl:when
            test="preceding::mei:staffGrp[mei:staffDef[@n=$thisStaff]]/mei:staffDef[@n=$thisStaff]">
            <xsl:value-of select="1"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$thisStaff"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <!-- At this point, voice = layer assigned in MEI -->
      <xsl:attribute name="voice">
        <xsl:choose>
          <xsl:when test="ancestor::mei:layer">
            <xsl:value-of select="ancestor::mei:layer/@n"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="1"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </comment>
  </xsl:template>

  <xsl:template match="mei:staffDef" mode="partList">
    <score-part>
      <xsl:attribute name="id">
        <xsl:choose>
          <xsl:when test="@xml:id">
            <xsl:value-of select="@xml:id"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>P_</xsl:text>
            <xsl:value-of select="generate-id()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <part-name-display>
        <xsl:choose>
          <xsl:when test="@label">
            <xsl:value-of select="@label"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:staffGrp[@label]">
            <xsl:value-of select="ancestor::mei:staffGrp[@label][1]/@label"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>MusicXML Part</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </part-name-display>
      <xsl:if test="@label.abbr">
        <part-abbreviation-display>
          <display-text>
            <xsl:value-of select="@label.abbr"/>
          </display-text>
        </part-abbreviation-display>
      </xsl:if>
      <xsl:apply-templates select="mei:instrDef" mode="partList"/>
    </score-part>
  </xsl:template>

  <xsl:template match="mei:staffGrp" mode="partList">
    <!-- The assignment of staffGrp and staffDef elements to MusicXML parts
      depends on the occurrence of instrDef or the use of @xml:id. When a staffGrp
      has a single instrument definition or has an xml:id attribute, then it becomes 
      a part. Otherwise, each staff definition is a part. -->
    <xsl:choose>
      <xsl:when test="count(mei:instrDef) = 1">
        <!-- The staff group constitutes a single part -->
        <score-part>
          <xsl:attribute name="id">
            <xsl:value-of select="@xml:id"/>
          </xsl:attribute>
          <part-name-display>
            <xsl:choose>
              <xsl:when test="@label">
                <xsl:value-of select="@label"/>
              </xsl:when>
              <xsl:when test="ancestor::mei:staffGrp[@label]">
                <xsl:value-of select="ancestor::mei:staffGrp[@label][1]/@label"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>MusicXML Part</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </part-name-display>
          <xsl:if test="@label.abbr">
            <part-abbreviation-display>
              <display-text>
                <xsl:value-of select="@label.abbr"/>
              </display-text>
            </part-abbreviation-display>
          </xsl:if>
          <xsl:apply-templates select="mei:instrDef" mode="partList"/>
        </score-part>
      </xsl:when>
      <xsl:when test="@xml:id">
        <!-- The staff group constitutes a single part -->
        <!-- Can this be OR'd with the condition above? -->
        <score-part>
          <xsl:attribute name="id">
            <xsl:value-of select="@xml:id"/>
          </xsl:attribute>
          <part-name-display>
            <xsl:choose>
              <xsl:when test="@label">
                <xsl:value-of select="@label"/>
              </xsl:when>
              <xsl:when test="ancestor::mei:staffGrp[@label]">
                <xsl:value-of select="ancestor::mei:staffGrp[@label][1]/@label"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>MusicXML Part</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </part-name-display>
          <xsl:if test="@label.abbr">
            <part-abbreviation-display>
              <display-text>
                <xsl:value-of select="@label.abbr"/>
              </display-text>
            </part-abbreviation-display>
          </xsl:if>
          <xsl:apply-templates select="mei:instrDef" mode="partList"/>
        </score-part>
      </xsl:when>
      <!-- each staffGrp or staffDef is a separate part -->
      <xsl:otherwise>
        <xsl:apply-templates select="mei:staffDef | mei:staffGrp" mode="partList"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mei:work | mei:source">
    <!-- Both work and source descriptions result in MusicXML work description -->
    <work>
      <xsl:for-each select="mei:titleStmt/descendant::mei:identifier[1]">
        <work-number>
          <xsl:value-of select="."/>
        </work-number>
      </xsl:for-each>
      <xsl:choose>
        <xsl:when test="mei:titleStmt/mei:title[@type='uniform']">
          <xsl:for-each select="mei:titleStmt/mei:title[@type='uniform'][1]">
            <xsl:variable name="workTitle">
              <xsl:apply-templates select="." mode="workTitle"/>
            </xsl:variable>
            <work-title>
              <xsl:value-of select="replace(normalize-space($workTitle), '(,|;|:|\.|\s)+$', '')"/>
            </work-title>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="mei:titleStmt/mei:title[@label='work']">
          <xsl:variable name="workTitle">
            <xsl:for-each select="mei:titleStmt/mei:title[@label='work']">
              <xsl:apply-templates select="mei:*[not(local-name()='title' and @label='movement')] |
                text()" mode="workTitle"/>
              <xsl:if test="position() != last()">
                <xsl:text> ; </xsl:text>
              </xsl:if>
            </xsl:for-each>
          </xsl:variable>
          <work-title>
            <xsl:value-of select="replace(normalize-space($workTitle), '(,|;|:|\.|\s)+$', '')"/>
          </work-title>
        </xsl:when>
        <xsl:when test="mei:titleStmt/mei:title[not(@label='movement')]">
          <xsl:variable name="workTitle">
            <xsl:for-each select="mei:titleStmt/mei:title[not(@label='movement')]">
              <xsl:apply-templates select="." mode="workTitle"/>
              <xsl:if test="position() != last()">
                <xsl:text> ; </xsl:text>
              </xsl:if>
            </xsl:for-each>
          </xsl:variable>
          <work-title>
            <xsl:value-of select="replace(normalize-space($workTitle), '(,|;|:|\.|\s)+$', '')"/>
          </work-title>
        </xsl:when>
      </xsl:choose>
    </work>
    <xsl:if test="mei:titleStmt//mei:title[@label='movement']">
      <xsl:variable name="movementTitle">
        <xsl:for-each select="mei:titleStmt//mei:title[@label='movement']">
          <xsl:apply-templates select="." mode="workTitle"/>
          <xsl:if test="position() != last()">
            <xsl:text> ; </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <movement-title>
        <xsl:value-of select="replace(normalize-space($movementTitle), '(,|;|:|\.|\s)+$', '')"/>
      </movement-title>
    </xsl:if>
    <identification>
      <xsl:choose>
        <xsl:when test="mei:titleStmt/mei:respStmt/mei:resp">
          <xsl:for-each select="mei:titleStmt/mei:respStmt/mei:resp">
            <creator>
              <xsl:attribute name="type">
                <xsl:value-of select="."/>
              </xsl:attribute>
              <xsl:value-of select="following-sibling::mei:name[1]"/>
            </creator>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="mei:titleStmt/mei:respStmt[mei:name or mei:persName or mei:corpName]">
          <xsl:for-each select="mei:titleStmt/mei:respStmt">
            <xsl:for-each select="mei:name | mei:persName | mei:corpName">
              <creator>
                <xsl:attribute name="type">
                  <xsl:value-of select="@role"/>
                </xsl:attribute>
                <xsl:value-of select="."/>
              </creator>
            </xsl:for-each>
          </xsl:for-each>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="ancestor::mei:meiHead/mei:fileDesc/mei:pubStmt/mei:availability"/>
      <encoding>
        <software>
          <xsl:value-of select="$progName"/>
          <xsl:text>&#32;</xsl:text>
          <xsl:value-of select="$progVersion"/>
        </software>
        <encoding-date>
          <xsl:value-of select="format-date(current-date(), '[Y]-[M02]-[D02]')"/>
        </encoding-date>
      </encoding>
      <!-- the source for the conversion is the MEI file -->
      <source>
        <xsl:variable name="source">
          <xsl:apply-templates select="ancestor::mei:meiHead/mei:fileDesc" mode="source"/>
        </xsl:variable>
        <xsl:text>MEI encoding</xsl:text>
        <xsl:choose>
          <xsl:when test="normalize-space($source) != ''">
            <xsl:text>:&#32;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>.</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="$source"/>
      </source>
      <!-- miscellaneous information -->
      <xsl:if test="ancestor::mei:meiHead//mei:notesStmt[mei:annot[@label]]">
        <miscellaneous>
          <xsl:for-each select="ancestor::mei:meiHead//mei:notesStmt[mei:annot]/mei:annot[@label]">
            <miscellaneous-field>
              <xsl:attribute name="name">
                <xsl:value-of select="@label"/>
              </xsl:attribute>
              <xsl:value-of select="."/>
            </miscellaneous-field>
          </xsl:for-each>
        </miscellaneous>
      </xsl:if>
    </identification>
  </xsl:template>

  <!-- Named templates -->  
  <xsl:template name="gesturalDurationFromWrittenDuration">
    <!-- Calculate quantized value (in ppq units) -->
    <xsl:param name="ppq"/>
    <xsl:param name="writtenDur"/>
    <xsl:param name="dots"/>

    <xsl:variable name="thisEventID">
      <xsl:value-of select="@xml:id"/>
    </xsl:variable>

    <!-- written duration in ppq units -->
    <xsl:variable name="baseDur">
      <xsl:choose>
        <xsl:when test="$writtenDur = 'long'">
          <xsl:value-of select="$ppq * 16"/>
        </xsl:when>
        <xsl:when test="$writtenDur = 'breve'">
          <xsl:value-of select="$ppq * 8"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '1'">
          <xsl:value-of select="$ppq * 4"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '2'">
          <xsl:value-of select="$ppq * 2"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '4'">
          <xsl:value-of select="$ppq"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '8'">
          <xsl:value-of select="$ppq div 2"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '16'">
          <xsl:value-of select="$ppq div 4"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '32'">
          <xsl:value-of select="$ppq div 8"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '64'">
          <xsl:value-of select="$ppq div 16"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '128'">
          <xsl:value-of select="$ppq div 32"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '256'">
          <xsl:value-of select="$ppq div 64"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '512'">
          <xsl:value-of select="$ppq div 128"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '1024'">
          <xsl:value-of select="$ppq div 256"/>
        </xsl:when>
        <xsl:when test="$writtenDur = '2048'">
          <xsl:value-of select="$ppq div 512"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!-- ppq value of dots -->
    <xsl:variable name="dotClicks">
      <xsl:choose>
        <xsl:when test="$dots = 1">
          <xsl:value-of select="$baseDur div 2"/>
        </xsl:when>
        <xsl:when test="$dots = 2">
          <xsl:value-of select="($baseDur div 2) div 2"/>
        </xsl:when>
        <xsl:when test="$dots = 3">
          <xsl:value-of select="(($baseDur div 2) div 2) div 2"/>
        </xsl:when>
        <xsl:when test="$dots = 4">
          <xsl:value-of select="((($baseDur div 2) div 2) div 2) div 2"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="0"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <!-- Is this event a participant in a tuplet? -->
    <xsl:variable name="tupletRatio">
      <xsl:choose>
        <xsl:when test="ancestor::mei:tuplet">
          <xsl:value-of select="concat(ancestor::mei:tuplet[1]/@num, ':',
            ancestor::mei:tuplet[1]/@numbase)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="following::mei:tupletSpan">
            <xsl:variable name="tupletParticipants">
              <xsl:value-of select="concat(@startid, '&#32;', @plist, '&#32;', @endid, '&#32;')"/>
            </xsl:variable>
            <xsl:if test="contains($tupletParticipants, concat('#', $thisEventID, '&#32;'))">
              <xsl:value-of select="concat(@num, ':', @numbase)"/>
            </xsl:if>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <!-- modify the gestural duration determined above using the tuplet ratio -->
      <xsl:when test="$tupletRatio != ''">
        <xsl:variable name="num">
          <xsl:value-of select="number(substring-before($tupletRatio, ':'))"/>
        </xsl:variable>
        <xsl:variable name="numbase">
          <xsl:value-of select="number(substring-after($tupletRatio, ':'))"/>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="($baseDur + $dotClicks) &gt; $ppq">
            <xsl:value-of select="format-number((($baseDur + $dotClicks) * $num) div $numbase,
              '###0')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="format-number((($baseDur + $dotClicks) * $numbase) div $num,
              '###0')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- return the unmodified gestural duration -->
      <xsl:otherwise>
        <xsl:value-of select="($baseDur + $dotClicks)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="measureDuration">
    <!-- calculates duration of a measure in ppq units -->
    <xsl:param name="meterCount"/>
    <xsl:param name="meterUnit"/>
    <xsl:param name="ppq"/>
    <!--DEBUG:-->
    <!--<xsl:variable name="errorMessage">
      <xsl:text>meterCount=</xsl:text>
      <xsl:value-of select="$meterCount"/>
      <xsl:text>, meterUnit=</xsl:text>
      <xsl:value-of select="$meterUnit"/>
      <xsl:text>, ppq=</xsl:text>
      <xsl:value-of select="$ppq"/>
    </xsl:variable>
    <xsl:message>
      <xsl:value-of select="$errorMessage"/>
    </xsl:message>-->
    <xsl:choose>
      <xsl:when test="$meterUnit = 1">
        <xsl:value-of select="($meterCount * 4) * $ppq"/>
      </xsl:when>
      <xsl:when test="$meterUnit = 2">
        <xsl:value-of select="($meterCount * $meterUnit) * $ppq"/>
      </xsl:when>
      <xsl:when test="$meterUnit = 4">
        <xsl:value-of select="$meterCount * $ppq"/>
      </xsl:when>
      <xsl:when test="$meterUnit &gt; 4">
        <xsl:value-of select="($meterCount div ($meterUnit div ($meterUnit div 4))) * $ppq"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="rendition">
    <!-- creates renditional attributes -->
    <xsl:copy-of select="@halign | @rotation | @valign | @xml:lang | @xml:space"/>
    <!-- color has to be converted to AARRGGBB -->
    <xsl:if test="@fontfam">
      <xsl:attribute name="font-family">
        <xsl:value-of select="@fontfam"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@fontsize">
      <xsl:attribute name="font-size">
        <xsl:value-of select="@fontsize"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@fontstyle">
      <xsl:attribute name="font-style">
        <xsl:value-of select="@fontstyle"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@fontweight">
      <xsl:attribute name="font-weight">
        <xsl:value-of select="@fontweight"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:if test="@rend">
      <xsl:analyze-string select="@rend" regex="\s+">
        <xsl:non-matching-substring>
          <xsl:choose>
            <xsl:when test="matches(., '^underline$')">
              <xsl:attribute name="underline">
                <xsl:value-of select="1"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'underline\(\d+\)')">
              <xsl:attribute name="underline">
                <xsl:value-of select="replace(., '.*\((\d+)\)', '$1')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '^overline$')">
              <xsl:attribute name="overline">
                <xsl:value-of select="1"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'overline\(\d+\)')">
              <xsl:attribute name="overline">
                <xsl:value-of select="replace(., '.*\((\d+)\)', '$1')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '^(line-through|strike)$')">
              <xsl:attribute name="line-through">
                <xsl:value-of select="1"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '(line-through|strike)\(\d+\)')">
              <xsl:attribute name="line-through">
                <xsl:value-of select="replace(., '.*\((\d+)\)', '$1')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'letter-spacing\((\+|-)?\d+(\.\d+)?\)')">
              <xsl:attribute name="letter-spacing">
                <xsl:value-of select="replace(., '.*\(((\+|-)?\d+(\.\d+)?)\)', '$1')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'line-height\((\+|-)?\d+(\.\d+)?\)')">
              <xsl:attribute name="line-height">
                <xsl:value-of select="replace(., '.*\(((\+|-)?\d+(\.\d+)?)\)', '$1')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '(bold|bolder)')">
              <xsl:attribute name="font-weight">
                <xsl:text>bold</xsl:text>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '(box|circle|dbox|tbox)')">
              <xsl:attribute name="enclosure">
                <xsl:value-of select="replace(replace(replace(replace(., 'box', 'rectangle'),
                  'circle', 'circle'), 'dbox', 'diamond'), 'tbox', 'triangle')"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., '(lro|ltr|rlo|rtl)')">
              <xsl:attribute name="dir">
                <xsl:value-of select="."/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(.,
              '(large|medium|small|x-large|x-small|xx-large|xx-small)')">
              <xsl:attribute name="font-size">
                <xsl:value-of select="."/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'italic')">
              <xsl:attribute name="font-style">
                <xsl:value-of select="."/>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="matches(., 'none')">
              <xsl:attribute name="print-object">
                <xsl:text>no</xsl:text>
              </xsl:attribute>
            </xsl:when>
          </xsl:choose>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mei:*[ancestor::*[starts-with(local-name(), 'pg')]]/*[not(local-name()='lb'
    or local-name()='rend')]" mode="stage1">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>

  <!-- Default template for addTstamp.ges -->
  <xsl:template match="@* | node() | comment()" mode="addTstamp.ges">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="addTstamp.ges"/>
    </xsl:copy>
  </xsl:template>

  <!-- Default template for dropPPQ mode -->
  <xsl:template match="@* | node() | comment()" mode="dropPPQ">
    <xsl:copy>
      <xsl:copy-of select="@*[not(local-name()='ppq')]"/>
      <xsl:apply-templates mode="dropPPQ"/>
    </xsl:copy>
  </xsl:template>

  <!-- Default template for stage 1 -->
  <xsl:template match="@* | node() | comment()" mode="stage1">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="stage1"/>
    </xsl:copy>
  </xsl:template>

  <!-- Default template for stage2 -->
  <xsl:template match="@* | node() | comment()" mode="stage2">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="stage2"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="measure" mode="stage2">
    <xsl:copy>
      <xsl:if test="@n">
        <xsl:attribute name="number">
          <xsl:value-of select="@n"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@width">
        <xsl:attribute name="width">
          <xsl:value-of select="format-number(@width * 5, '###0.####')"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@metcon">
        <xsl:attribute name="implicit">
          <xsl:choose>
            <xsl:when test="@metcon='true'">
              <xsl:text>no</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>yes</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates mode="stage2"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="part" mode="stage2">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <!-- left barline -->
      <xsl:choose>
        <xsl:when test="ancestor::measure/@left">
          <barline location="left">
            <xsl:choose>
              <xsl:when test="ancestor::measure/@left='dashed'">
                <bar-style>dashed</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='dotted'">
                <bar-style>dotted</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='dbl'">
                <bar-style>light-light</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='dbldashed'">
                <xsl:comment>MusicXML doesn't support double dashed barlines</xsl:comment>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='dbldotted'">
                <xsl:comment>MusicXML doesn't support double dotted barlines</xsl:comment>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='end'">
                <bar-style>light-heavy</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@left='invis'">
                <bar-style>none</bar-style>
              </xsl:when>
            </xsl:choose>
          </barline>
        </xsl:when>
        <xsl:when test="ancestor::measure/preceding::measure[1][@right='rptstart' or
          @right='rptboth']">
          <barline location="left">
            <xsl:choose>
              <xsl:when test="ancestor::measure/preceding::measure[1]/@right='rptstart'">
                <bar-style>heavy-light</bar-style>
                <repeat direction="forward"/>
              </xsl:when>
              <xsl:when test="ancestor::measure/preceding::measure[1]/@right='rptboth'">
                <bar-style>light-light</bar-style>
                <repeat direction="forward"/>
              </xsl:when>
            </xsl:choose>
          </barline>
        </xsl:when>
      </xsl:choose>

      <xsl:apply-templates select="events/*" mode="stage2"/>

      <!--<xsl:apply-templates select="*[local-name() != 'controlevents' and local-name() != 'sb' and
        local-name() != 'scoreDef']" mode="stage2"/>-->

      <!-- right barline -->
      <xsl:choose>
        <xsl:when test="ancestor::measure/@right">
          <barline location="right">
            <xsl:choose>
              <xsl:when test="ancestor::measure/@right='dashed'">
                <bar-style>dashed</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='dotted'">
                <bar-style>dotted</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='dbl'">
                <bar-style>light-light</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='dbldashed'">
                <xsl:comment>MusicXML doesn't support double dashed barlines</xsl:comment>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='dbldotted'">
                <xsl:comment>MusicXML doesn't support double dotted barlines</xsl:comment>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='end'">
                <bar-style>light-heavy</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='invis'">
                <bar-style>none</bar-style>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='rptstart'">
                <bar-style>heavy-light</bar-style>
                <repeat direction="forward"/>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='rptboth'">
                <bar-style>light-heavy</bar-style>
                <repeat direction="backward"/>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='rptend'">
                <bar-style>light-heavy</bar-style>
                <repeat direction="backward"/>
              </xsl:when>
              <xsl:when test="ancestor::measure/@right='single'">
                <bar-style>regular</bar-style>
              </xsl:when>
            </xsl:choose>
          </barline>
        </xsl:when>
        <xsl:when test="ancestor::measure/following::measure[1][@left='rptend' or @left='rptboth']">
          <xsl:choose>
            <xsl:when test="ancestor::measure/following::measure[1]/@left='rptend'">
              <bar-style>heavy-light</bar-style>
              <repeat direction="backward"/>
            </xsl:when>
            <xsl:when test="ancestor::measure/following::measure[1]/@left='rptboth'">
              <bar-style>light-light</bar-style>
              <repeat direction="backward"/>
            </xsl:when>
          </xsl:choose>
        </xsl:when>
      </xsl:choose>
    </xsl:copy>
  </xsl:template>

  <!-- The following templates were labelled mode="partContent"; now they will 
  be used in stage 2 of the conversion; that is, for the actual jump from
  MusicXML-like MEI markup to actual MusicXML markup. -->
  <!--<xsl:template match="backup" mode="stage2">
    <xsl:copy-of select="."/>
  </xsl:template>-->

  <!--<xsl:template match="mei:beam | mei:chord | mei:tuplet" mode="stage2">
    <xsl:apply-templates mode="stage2"/>
  </xsl:template>-->

  <!--<xsl:template match="mei:clef" mode="stage2">
    <attributes>
      <clef>
        <xsl:attribute name="number">
          <xsl:value-of select="@partStaff"/>
        </xsl:attribute>
        <sign>
          <xsl:value-of select="@shape"/>
        </sign>
        <line>
          <xsl:value-of select="@line"/>
        </line>
      </clef>
    </attributes>
  </xsl:template>-->

  <!--<xsl:template match="mei:mRest | mei:mSpace | mei:rest | mei:space" mode="stage2">
    <note>

      <!-\- DEBUG: -\->
      <!-\-<xsl:copy-of select="@*"/>-\->

      <xsl:if test="local-name()='space' or local-name()='mSpace'">
        <xsl:attribute name="print-object">
          <xsl:text>no</xsl:text>
        </xsl:attribute>
      </xsl:if>
      <rest>
        <xsl:if test="@ploc">
          <display-step>
            <xsl:value-of select="upper-case(@ploc)"/>
          </display-step>
        </xsl:if>
        <xsl:if test="@oloc">
          <display-octave>
            <xsl:value-of select="@oloc"/>
          </display-octave>
        </xsl:if>
      </rest>
      <xsl:choose>
        <xsl:when test="@dur.ges = 0">
          <!-\- This is a grace note that has no explicit performed duration -\->
        </xsl:when>
        <xsl:when test="@dur.ges">
          <duration>
            <xsl:value-of select="@dur.ges"/>
          </duration>
        </xsl:when>
        <xsl:when test="ancestor::mei:*[@dur.ges]">
          <duration>
            <xsl:value-of select="ancestor::mei:*[@dur.ges][1]/@dur.ges"/>
          </duration>
        </xsl:when>
      </xsl:choose>
      <voice>
        <xsl:choose>
          <xsl:when test="@voice">
            <xsl:value-of select="@voice"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:*[@voice]">
            <xsl:value-of select="ancestor::mei:*[@voice][1]/@voice"/>
          </xsl:when>
        </xsl:choose>
      </voice>
      <xsl:if test="@dur or ancestor::mei:*[@dur]">
        <type>
          <xsl:choose>
            <xsl:when test="@dur">
              <xsl:choose>
                <xsl:when test="@dur='breve' or @dur='long' or @dur='maxima'">
                  <xsl:value-of select="@dur"/>
                </xsl:when>
                <xsl:when test="@dur='1'">
                  <xsl:text>whole</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='2'">
                  <xsl:text>half</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='4'">
                  <xsl:text>quarter</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='8'">
                  <xsl:text>eighth</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='16' or @dur='32' or @dur='64' or @dur='128' or @dur='256' or
                  @dur='512' or @dur='1024'">
                  <xsl:value-of select="@dur"/>
                  <xsl:text>th</xsl:text>
                </xsl:when>
              </xsl:choose>
            </xsl:when>
            <xsl:when test="ancestor::mei:*[@dur]">
              <xsl:choose>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='breve' or
                  ancestor::mei:*[@dur][1]/@dur='long' or ancestor::mei:*[@dur][1]/@dur='maxima'">
                  <xsl:value-of select="ancestor::mei:*[@dur][1]/@dur"/>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='1'">
                  <xsl:text>whole</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='2'">
                  <xsl:text>half</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='4'">
                  <xsl:text>quarter</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='8'">
                  <xsl:text>eighth</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='16' or
                  ancestor::mei:*[@dur][1]/@dur='32' or ancestor::mei:*[@dur][1]/@dur='64' or
                  ancestor::mei:*[@dur][1]/@dur='128' or ancestor::mei:*[@dur][1]/@dur='256' or
                  ancestor::mei:*[@dur][1]/@dur='512' or ancestor::mei:*[@dur][1]/@dur='1024'">
                  <xsl:value-of select="ancestor::mei:*[@dur][1]/@dur"/>
                  <xsl:text>th</xsl:text>
                </xsl:when>
              </xsl:choose>
            </xsl:when>
            <xsl:when test="@dur.ges">
              <!-\- Map @dur.ges to written value? -\->
            </xsl:when>
          </xsl:choose>
        </type>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="@dots">
          <xsl:for-each select="1 to @dots">
            <dot/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="ancestor::mei:*[@dots]">
          <xsl:for-each select="1 to ancestor::mei:*[@dots][1]/@dots">
            <dot/>
          </xsl:for-each>
        </xsl:when>
      </xsl:choose>
      <staff>
        <xsl:choose>
          <xsl:when test="@partStaff">
            <xsl:value-of select="@partStaff"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:*[@partStaff]">
            <xsl:value-of select="ancestor::mei:*[@partStaff][1]/@partStaff"/>
          </xsl:when>
        </xsl:choose>
      </staff>
    </note>
  </xsl:template> -->

  <!--<xsl:template match="mei:note" mode="stage2">
    <note>

      <!-\- DEBUG: -\->
      <!-\-<xsl:copy-of select="@*"/>-\->

      <!-\- DEBUG: -\->
      <!-\-<xsl:if test="ancestor::mei:chord">
        <xsl:copy-of select="ancestor::mei:chord/@*[not(local-name() = 'id')]"/>
      </xsl:if>-\->

      <xsl:if test="ancestor::mei:chord and preceding-sibling::mei:note">
        <chord/>
      </xsl:if>
      <xsl:if test="@grace">
        <grace>
          <xsl:if test="matches(@stem.mod, 'slash')">
            <xsl:attribute name="slash">
              <xsl:text>yes</xsl:text>
            </xsl:attribute>
          </xsl:if>
        </grace>
      </xsl:if>
      <pitch>
        <step>
          <xsl:value-of select="upper-case(@pname)"/>
        </step>
        <xsl:if test="@accid.ges">
          <alter>
            <xsl:choose>
              <xsl:when test="@accid.ges = 'f'">
                <xsl:text>-1</xsl:text>
              </xsl:when>
              <xsl:when test="@accid.ges = 's'">
                <xsl:text>1</xsl:text>
              </xsl:when>
            </xsl:choose>
          </alter>
        </xsl:if>
        <octave>
          <xsl:choose>
            <xsl:when test="@oct.ges">
              <xsl:value-of select="@oct.ges"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@oct"/>
            </xsl:otherwise>
          </xsl:choose>
        </octave>
      </pitch>
      <xsl:choose>
        <xsl:when test="@dur.ges = 0">
          <!-\- This is a grace note that has no explicit performed duration -\->
        </xsl:when>
        <xsl:when test="@dur.ges">
          <duration>
            <xsl:value-of select="@dur.ges"/>
          </duration>
        </xsl:when>
        <xsl:when test="ancestor::mei:*[@dur.ges]">
          <duration>
            <xsl:value-of select="ancestor::mei:*[@dur.ges][1]/@dur.ges"/>
          </duration>
        </xsl:when>
      </xsl:choose>
      <voice>
        <xsl:choose>
          <xsl:when test="@voice">
            <xsl:value-of select="@voice"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:*[@voice]">
            <xsl:value-of select="ancestor::mei:*[@voice][1]/@voice"/>
          </xsl:when>
        </xsl:choose>
      </voice>
      <xsl:if test="@dur or ancestor::mei:*[@dur]">
        <type>
          <xsl:choose>
            <xsl:when test="@dur">
              <xsl:choose>
                <xsl:when test="@dur='breve' or @dur='long' or @dur='maxima'">
                  <xsl:value-of select="@dur"/>
                </xsl:when>
                <xsl:when test="@dur='1'">
                  <xsl:text>whole</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='2'">
                  <xsl:text>half</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='4'">
                  <xsl:text>quarter</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='8'">
                  <xsl:text>eighth</xsl:text>
                </xsl:when>
                <xsl:when test="@dur='16' or @dur='32' or @dur='64' or @dur='128' or @dur='256' or
                  @dur='512' or @dur='1024'">
                  <xsl:value-of select="@dur"/>
                  <xsl:text>th</xsl:text>
                </xsl:when>
              </xsl:choose>
            </xsl:when>
            <xsl:when test="ancestor::mei:*[@dur]">
              <xsl:choose>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='breve' or
                  ancestor::mei:*[@dur][1]/@dur='long' or ancestor::mei:*[@dur][1]/@dur='maxima'">
                  <xsl:value-of select="ancestor::mei:*[@dur][1]/@dur"/>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='1'">
                  <xsl:text>whole</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='2'">
                  <xsl:text>half</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='4'">
                  <xsl:text>quarter</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='8'">
                  <xsl:text>eighth</xsl:text>
                </xsl:when>
                <xsl:when test="ancestor::mei:*[@dur][1]/@dur='16' or
                  ancestor::mei:*[@dur][1]/@dur='32' or ancestor::mei:*[@dur][1]/@dur='64' or
                  ancestor::mei:*[@dur][1]/@dur='128' or ancestor::mei:*[@dur][1]/@dur='256' or
                  ancestor::mei:*[@dur][1]/@dur='512' or ancestor::mei:*[@dur][1]/@dur='1024'">
                  <xsl:value-of select="ancestor::mei:*[@dur][1]/@dur"/>
                  <xsl:text>th</xsl:text>
                </xsl:when>
              </xsl:choose>
            </xsl:when>
            <xsl:when test="@dur.ges">
              <!-\- Map @dur.ges to written value? -\->
            </xsl:when>
          </xsl:choose>
        </type>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="@dots">
          <xsl:for-each select="1 to @dots">
            <dot/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="ancestor::mei:*[@dots]">
          <xsl:for-each select="1 to ancestor::mei:*[@dots][1]/@dots">
            <dot/>
          </xsl:for-each>
        </xsl:when>
      </xsl:choose>
      <xsl:if test="@accid">
        <accidental>
          <xsl:choose>
            <xsl:when test="@accid='f'">
              <xsl:text>flat</xsl:text>
            </xsl:when>
            <xsl:when test="@accid='s'">
              <xsl:text>sharp</xsl:text>
            </xsl:when>
            <xsl:when test="@accid='n'">
              <xsl:text>natural</xsl:text>
            </xsl:when>
          </xsl:choose>
        </accidental>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="@stem.dir">
          <stem>
            <xsl:value-of select="@stem.dir"/>
          </stem>
        </xsl:when>
        <xsl:when test="ancestor::mei:*[@stem.dir]">
          <stem>
            <xsl:value-of select="ancestor::mei:*[@stem.dir][1]/@stem.dir"/>
          </stem>
        </xsl:when>
      </xsl:choose>
      <staff>
        <xsl:choose>
          <xsl:when test="@partStaff">
            <xsl:value-of select="@partStaff"/>
          </xsl:when>
          <xsl:when test="ancestor::mei:*[@partStaff]">
            <xsl:value-of select="ancestor::mei:*[@partStaff][1]/@partStaff"/>
          </xsl:when>
        </xsl:choose>
      </staff>

      <!-\- So-called "notations" attached to individual notes -\->
      <!-\- Processing MEI control events into MusicXML notations requires checking the
      control event's startid (and sometimes endid) against the current event ID. -\->
      <xsl:variable name="thisEventID">
        <xsl:value-of select="@xml:id"/>
      </xsl:variable>

      <!-\- The following variables, e.g., $accidentalMarks, $arpeggiation, etc., 
      collect MusicXML elements. Later, if found not to be empty, their contents
      are copied to <notations> sub-elements. -\->

      <!-\- Editorial and cautionary accidentals -\->
      <xsl:variable name="accidentalMarks">
        <xsl:for-each select="mei:accid[@place='above' or @place='below' or @func='edit' or
          @func='caution']">
          <accidental-mark>
            <xsl:if test="@place">
              <xsl:attribute name="placement">
                <xsl:value-of select="@place"/>
              </xsl:attribute>
            </xsl:if>
            <xsl:choose>
              <xsl:when test="@accid='s'">
                <xsl:text>sharp</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='n'">
                <xsl:text>natural</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='f'">
                <xsl:text>flat</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='x'">
                <xsl:text>double-sharp</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='ff'">
                <xsl:text>double-flat</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='ss'">
                <xsl:text>sharp-sharp</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='ns'">
                <xsl:text>natural-sharp</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='nf'">
                <xsl:text>natural-flat</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='fd'">
                <xsl:text>flat-down</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='fu'">
                <xsl:text>flat-up</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='nd'">
                <xsl:text>natural-down</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='nu'">
                <xsl:text>natural-up</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='sd'">
                <xsl:text>sharp-down</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='su'">
                <xsl:text>sharp-up</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='ts'">
                <xsl:text>triple-sharp</xsl:text>
              </xsl:when>
              <xsl:when test="@accid='tf'">
                <xsl:text>triple-flat</xsl:text>
              </xsl:when>
            </xsl:choose>
          </accidental-mark>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Arpeggiation in MEI is a control event. -\->
      <xsl:variable name="arpeggiation">
        <xsl:for-each select="following::controlevents/mei:arpeg[not(@order='nonarp')]">
          <xsl:analyze-string select="@plist" regex="\s+">
            <xsl:non-matching-substring>
              <xsl:if test="substring(.,2)=$thisEventID">
                <arpeggiate/>
              </xsl:if>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:for-each>
        <xsl:for-each select="following::controlevents/mei:arpeg[@order='nonarp']">
          <xsl:variable name="firstNoteID">
            <xsl:value-of select="substring(replace(@plist,'^([^\s]+)\s+.*', '$1'), 2)"/>
          </xsl:variable>
          <xsl:variable name="lastNoteID">
            <xsl:value-of select="substring(replace(@plist,'^.*\s+([^\s]+)$','$1'), 2)"/>
          </xsl:variable>
          <xsl:if test="matches($thisEventID, $firstNoteID) or matches($thisEventID, $lastNoteID)">
            <non-arpeggiate>
              <xsl:attribute name="type">
                <xsl:choose>
                  <xsl:when test="matches($thisEventID, $firstNoteID)">
                    <xsl:text>bottom</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches($thisEventID, $lastNoteID)">
                    <xsl:text>top</xsl:text>
                  </xsl:when>
                </xsl:choose>
              </xsl:attribute>
            </non-arpeggiate>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Articulations -\->
      <xsl:variable name="articulations">
        <xsl:for-each select="mei:artic[@artic]">
          <xsl:variable name="articPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:analyze-string select="@artic" regex="\s+">
            <xsl:non-matching-substring>
              <xsl:variable name="articElement">
                <xsl:choose>
                  <xsl:when test="matches(., '^acc$')">
                    <xsl:text>accent</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^doit$')">
                    <xsl:text>doit</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^fall$')">
                    <xsl:text>falloff</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^marc$')">
                    <xsl:text>strong-accent</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^plop$')">
                    <xsl:text>plop</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^rip$')">
                    <xsl:text>scoop</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^spicc$')">
                    <xsl:text>spiccato</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^stacc$')">
                    <xsl:text>staccato</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^stacciss$')">
                    <xsl:text>staccatissimo</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^ten$')">
                    <xsl:text>tenuto</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^ten-stacc$')">
                    <xsl:text>detached-legato</xsl:text>
                  </xsl:when>
                </xsl:choose>
              </xsl:variable>
              <xsl:if test="$articElement != ''">
                <xsl:element name="{$articElement}">
                  <xsl:if test="($articPlace != '')">
                    <xsl:attribute name="placement">
                      <xsl:value-of select="$articPlace"/>
                    </xsl:attribute>
                  </xsl:if>
                </xsl:element>
              </xsl:if>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:for-each>

        <!-\- Some MusicXML "articulations" are MEI control events. -\->
        <xsl:for-each
          select="//controlevents/mei:dir[substring(@startid,2)=$thisEventID][@label='breath-mark'
          or @label='caesura' or @label='stress' or @label='unstress']">
          <xsl:variable name="articPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:variable name="articElement">
            <xsl:value-of select="@label"/>
          </xsl:variable>
          <xsl:if test="$articElement != ''">
            <xsl:element name="{$articElement}">
              <xsl:if test="($articPlace != '')">
                <xsl:attribute name="placement">
                  <xsl:value-of select="$articPlace"/>
                </xsl:attribute>
              </xsl:if>
              <xsl:if test="$articElement='breath-mark'">
                <xsl:choose>
                  <xsl:when test="matches(., &quot;&apos;&quot;)">
                    <xsl:text>tick</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., ',')">
                    <xsl:text>comma</xsl:text>
                  </xsl:when>
                </xsl:choose>
              </xsl:if>
            </xsl:element>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Fermatas are control events in MEI. -\->
      <xsl:variable name="fermatas">
        <xsl:for-each select="//controlevents/mei:fermata[substring(@startid,2)=$thisEventID]">
          <fermata>
            <xsl:attribute name="type">
              <xsl:choose>
                <xsl:when test="@form = 'inv'">
                  <xsl:text>inverted</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>upright</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
            <xsl:choose>
              <xsl:when test="@shape = 'square'">
                <xsl:text>square</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>normal</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </fermata>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Ornaments are control events in MEI. -\->
      <xsl:variable name="ornaments">
        <xsl:for-each select="//controlevents/mei:*[local-name()='mordent' or
          local-name()='trill' or local-name()='turn'][substring(@startid,2)=$thisEventID] |
          //controlevents/mei:dir[@label='shake' or
          @label='schleifer'][substring(@startid,2)=$thisEventID]">
          <xsl:variable name="ornamPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:variable name="ornamElement">
            <xsl:choose>
              <xsl:when test="local-name()='dir'">
                <xsl:value-of select="@label"/>
              </xsl:when>
              <xsl:when test="local-name()='mordent'">
                <xsl:choose>
                  <xsl:when test="@form='inv' and @label='shake'">
                    <xsl:text>shake</xsl:text>
                  </xsl:when>
                  <xsl:when test="@form='inv'">
                    <xsl:text>inverted-mordent</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="local-name()"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>
              <xsl:when test="local-name()='trill'">
                <xsl:text>trill-mark</xsl:text>
              </xsl:when>
              <xsl:when test="local-name()='turn'">
                <xsl:choose>
                  <xsl:when test="@form='inv' and @delayed='true'">
                    <xsl:text>delayed-inverted-turn</xsl:text>
                  </xsl:when>
                  <xsl:when test="@form='inv'">
                    <xsl:text>inverted-turn</xsl:text>
                  </xsl:when>
                  <xsl:when test="@delayed='true'">
                    <xsl:text>delayed-turn</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>turn</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>
            </xsl:choose>
          </xsl:variable>
          <xsl:if test="$ornamElement != ''">
            <xsl:element name="{$ornamElement}">
              <xsl:if test="($ornamPlace != '')">
                <xsl:attribute name="placement">
                  <xsl:value-of select="$ornamPlace"/>
                </xsl:attribute>
              </xsl:if>
            </xsl:element>
            <!-\- Accidentals attached to ornament -\->
            <xsl:if test="@accidupper">
              <accidental-mark>
                <xsl:attribute name="placement">
                  <xsl:text>above</xsl:text>
                </xsl:attribute>
                <xsl:analyze-string select="@accidupper" regex="\s+">
                  <xsl:non-matching-substring>
                    <xsl:choose>
                      <xsl:when test="normalize-space(.) = 's'">
                        <xsl:text>sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'n'">
                        <xsl:text>natural</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'f'">
                        <xsl:text>flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'x'">
                        <xsl:text>double-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ff'">
                        <xsl:text>double-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ss'">
                        <xsl:text>sharp-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ff'">
                        <xsl:text>flat-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ns'">
                        <xsl:text>natural-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nf'">
                        <xsl:text>natural-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'fd'">
                        <xsl:text>flat-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'fu'">
                        <xsl:text>flat-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nd'">
                        <xsl:text>natural-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nu'">
                        <xsl:text>natural-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'sd'">
                        <xsl:text>sharp-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'su'">
                        <xsl:text>sharp-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ts'">
                        <xsl:text>triple-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'tf'">
                        <xsl:text>triple-flat</xsl:text>
                      </xsl:when>
                    </xsl:choose>
                  </xsl:non-matching-substring>
                </xsl:analyze-string>
              </accidental-mark>
            </xsl:if>
            <xsl:if test="@accidlower">
              <accidental-mark>
                <xsl:attribute name="placement">
                  <xsl:text>below</xsl:text>
                </xsl:attribute>
                <xsl:analyze-string select="@accidlower" regex="\s+">
                  <xsl:non-matching-substring>
                    <xsl:choose>
                      <xsl:when test="normalize-space(.) = 's'">
                        <xsl:text>sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'n'">
                        <xsl:text>natural</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'f'">
                        <xsl:text>flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'x'">
                        <xsl:text>double-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ff'">
                        <xsl:text>double-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ss'">
                        <xsl:text>sharp-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ff'">
                        <xsl:text>flat-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ns'">
                        <xsl:text>natural-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nf'">
                        <xsl:text>natural-flat</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'fd'">
                        <xsl:text>flat-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'fu'">
                        <xsl:text>flat-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nd'">
                        <xsl:text>natural-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'nu'">
                        <xsl:text>natural-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'sd'">
                        <xsl:text>sharp-down</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'su'">
                        <xsl:text>sharp-up</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'ts'">
                        <xsl:text>triple-sharp</xsl:text>
                      </xsl:when>
                      <xsl:when test="normalize-space(.) = 'tf'">
                        <xsl:text>triple-flat</xsl:text>
                      </xsl:when>
                    </xsl:choose>
                  </xsl:non-matching-substring>
                </xsl:analyze-string>
              </accidental-mark>
            </xsl:if>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Technical/performance indications -\->
      <xsl:variable name="technical">
        <!-\- Some indications are MEI articulations. -\->
        <xsl:for-each select="mei:artic[@artic]">
          <xsl:variable name="techPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:analyze-string select="@artic" regex="\s+">
            <xsl:non-matching-substring>
              <xsl:variable name="techElement">
                <xsl:choose>
                  <!-\- technical -\->
                  <xsl:when test="matches(., '^bend$')">
                    <xsl:text>bend</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^dbltongue$')">
                    <xsl:text>double-tongue</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^dnbow$')">
                    <xsl:text>down-bow</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^fingernail$')">
                    <xsl:text>fingernails</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^harm$')">
                    <xsl:text>harmonic</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^heel$')">
                    <xsl:text>heel</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^open$')">
                    <xsl:text>open-string</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^snap$')">
                    <xsl:text>snap-pizzicato</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^stop$')">
                    <xsl:text>stopped</xsl:text>
                  </xsl:when>
                  <!-\- tap is recorded in a directive -\->
                  <xsl:when test="matches(., '^toe$')">
                    <xsl:text>toe</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^trpltongue$')">
                    <xsl:text>triple-tongue</xsl:text>
                  </xsl:when>
                  <xsl:when test="matches(., '^upbow$')">
                    <xsl:text>up-bow</xsl:text>
                  </xsl:when>
                </xsl:choose>
              </xsl:variable>
              <xsl:if test="$techElement != ''">
                <xsl:element name="{$techElement}">
                  <xsl:if test="($techPlace != '')">
                    <xsl:attribute name="placement">
                      <xsl:value-of select="$techPlace"/>
                    </xsl:attribute>
                  </xsl:if>
                </xsl:element>
              </xsl:if>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:for-each>

        <!-\- String tablature is recorded in event attributes. -\->
        <xsl:if test="@tab.string">
          <string>
            <xsl:value-of select="@tab.string"/>
          </string>
        </xsl:if>
        <xsl:if test="@tab.fret">
          <fret>
            <xsl:choose>
              <xsl:when test="@tab.fret='o'">
                <xsl:text>0</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@tab.fret"/>
              </xsl:otherwise>
            </xsl:choose>
          </fret>
        </xsl:if>

        <!-\- Other indications are MEI directives. -\->
        <xsl:for-each select="//controlevents/mei:dir[@label='pluck' or
          @label='tap'][substring(@startid,2)=$thisEventID]">
          <xsl:variable name="techPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:variable name="techElement">
            <xsl:value-of select="@label"/>
          </xsl:variable>
          <xsl:if test="$techElement != ''">
            <xsl:element name="{$techElement}">
              <xsl:if test="($techPlace != '')">
                <xsl:attribute name="placement">
                  <xsl:value-of select="$techPlace"/>
                </xsl:attribute>
              </xsl:if>
              <!-\- Copy content of directive -\->
              <xsl:copy-of select="node()"/>
            </xsl:element>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>

      <!-\- Dynamics and hammer-on and pull-off indications can potentially 
          cross measure boundaries, so must be "passed through" for processing
          later -\->

      <!-\-<xsl:variable name="dynamics">
          <xsl:for-each select="//controlevents/mei:dynam[substring(@startid,2)=$thisEventID]">
            <xsl:variable name="dynamPlace">
              <xsl:value-of select="@place"/>
            </xsl:variable>
            <xsl:variable name="dynamElement">
              <xsl:choose>
                <xsl:when test="matches(normalize-space(.),
                  '^(p|f){1,5}$|^m(f|p)$|^sf(p{1,2})?$|^sf{1,2}z$|^rfz?$|^fz$')">
                  <xsl:value-of select="."/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>other-dynamics</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="$dynamElement != ''">
              <xsl:element name="{$dynamElement}">
                <xsl:if test="($dynamPlace != '')">
                  <xsl:attribute name="placement">
                    <xsl:value-of select="$dynamPlace"/>
                  </xsl:attribute>
                </xsl:if>
                <!-\\- Copy directive content -\\->
                <xsl:if test="$dynamElement = 'other-dynamics'">
                  <xsl:value-of select="normalize-space(.)"/>
                </xsl:if>
              </xsl:element>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable> -\->

      <!-\- <xsl:for-each select="//controlevents/mei:dir[@label='hammer-on' or
          @label='pull-off'][substring(@startid,2)=$thisEventID]">
          <xsl:variable name="techPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:variable name="techElement">
            <xsl:value-of select="@label"/>
          </xsl:variable>
          <xsl:if test="$techElement != ''">
            <xsl:element name="{$techElement}">
              <xsl:if test="($techPlace != '')">
                <xsl:attribute name="placement">
                  <xsl:value-of select="$techPlace"/>
                </xsl:attribute>
              </xsl:if>
              <xsl:attribute name="type">
                <xsl:text>start</xsl:text>
              </xsl:attribute>
              <!-\\- Copy content of directive to start marker -\\->
              <xsl:copy-of select="node()"/>
            </xsl:element>
          </xsl:if>
        </xsl:for-each>
        <xsl:for-each select="//controlevents/mei:dir[@label='hammer-on' or
          @label='pull-off'][substring(@endid,2)=$thisEventID]">
          <xsl:variable name="techPlace">
            <xsl:value-of select="@place"/>
          </xsl:variable>
          <xsl:variable name="techElement">
            <xsl:value-of select="@label"/>
          </xsl:variable>
          <xsl:if test="$techElement != ''">
            <xsl:element name="{$techElement}">
              <xsl:if test="($techPlace != '')">
                <xsl:attribute name="placement">
                  <xsl:value-of select="$techPlace"/>
                </xsl:attribute>
              </xsl:if>
              <xsl:attribute name="type">
                <xsl:text>stop</xsl:text>
              </xsl:attribute>
            </xsl:element>
          </xsl:if>
        </xsl:for-each> -\->

      <!-\- If any of the preceding variables aren't empty, create a <notations> element
      and fill it with appropriate content. -\->
      <xsl:if test="$accidentalMarks/* or $arpeggiation/* or $articulations/* or $fermatas/*
        or $ornaments/* or $technical/*">
        <notations>
          <xsl:if test="$accidentalMarks/*">
            <xsl:copy-of select="$accidentalMarks/*"/>
          </xsl:if>
          <xsl:if test="$arpeggiation/*">
            <xsl:copy-of select="$arpeggiation/*"/>
          </xsl:if>
          <xsl:if test="$articulations/*">
            <articulations>
              <xsl:copy-of select="$articulations/*"/>
            </articulations>
          </xsl:if>
          <!-\-<xsl:if test="$dynamics/*">
            <xsl:for-each select="$dynamics/*">
              <dynamics>
                <xsl:copy-of select="@*"/>
                <xsl:variable name="elementName">
                  <xsl:value-of select="local-name()"/>
                </xsl:variable>
                <xsl:element name="{$elementName}">
                  <xsl:copy-of select="node()"/>
                </xsl:element>
              </dynamics>
            </xsl:for-each>
          </xsl:if>-\->
          <xsl:if test="$fermatas/*">
            <xsl:copy-of select="$fermatas/*"/>
          </xsl:if>
          <xsl:if test="$ornaments/*">
            <ornaments>
              <!-\- In MusicXML ornaments, e.g., trill, don't allow content so copy
              comments into parent <ornaments> element. -\->
              <xsl:for-each select="//controlevents/mei:*[local-name()='mordent' or
                local-name()='trill' or local-name()='turn'][substring(@startid,2)=$thisEventID] |
                //controlevents/mei:dir[@label='shake' or
                @label='schleifer'][substring(@startid,2)=$thisEventID]">
                <xsl:copy-of select="comment()"/>
              </xsl:for-each>
              <xsl:copy-of select="$ornaments/*"/>
            </ornaments>
          </xsl:if>
          <xsl:if test="$technical/*">
            <technical>
              <xsl:copy-of select="$technical/*"/>
            </technical>
          </xsl:if>
        </notations>
      </xsl:if>

      <xsl:for-each select="mei:verse">
        <lyric>
          <xsl:attribute name="number">
            <xsl:value-of select="@n"/>
          </xsl:attribute>
          <syllabic>
            <xsl:choose>
              <xsl:when test="mei:syl/@wordpos='i'">
                <xsl:text>begin</xsl:text>
              </xsl:when>
              <xsl:when test="mei:syl/@wordpos='m'">
                <xsl:text>middle</xsl:text>
              </xsl:when>
              <xsl:when test="mei:syl/@wordpos='t'">
                <xsl:text>end</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>single</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </syllabic>
          <xsl:for-each select="mei:syl">
            <text>
              <xsl:value-of select="."/>
            </text>
          </xsl:for-each>
        </lyric>
      </xsl:for-each>
    </note>
  </xsl:template>-->

</xsl:stylesheet>
