
class AdminMessages < ActiveRecord::Migration
  def self.up
    AdminMessage.create(:guid => 'Welcome', :text => 'Welcome to EPF Wiki, the Wiki technology for Eclipse Process Framework Composer.' )
    AdminMessage.create(:guid => 'About', :text => '<p>EPF Wiki is Wiki technology designed to be used together with Eclipse Process Framework (EPF). 
This offers the best of two distinct worlds: the worlds of powerful process frameworks and Wikis. 
It offers an process engineering infrastructure that combines a modular method construction approach and the flexibility and ease of use that is the defining characteristic of a Wiki. </p>
<p>EPF Wiki is an innovation that adds Wiki features to the hypertext process descriptions created with EPF Composer.</p>
<ul>
    <li><a href="/images/epfwiki_infra_overview.jpg">Overview EPF Wiki Infrastructure</a>
    </li>

</ul>

<h2>Eclipse Process Framework</h2>
<p>The Eclipse Process Framework (EPF) aims at producing a customizable software process enginering framework, with exemplary process content and tools, supporting a broad variety of project types and development styles</p>
<p>More information:
</p><ul>
    <li><a href="http://www.eclipse.org/epf/">EPF Project</a>
    </li>

    <li><a href="http://www.eclipse.org/epf/general/getting_started.php">Getting Started with EPF</a>
    </li>
</ul>



<h2>Rules of Conduct</h2>
<p>If you want to contribute to the process descriptions published here, you are welcome to do so. 
You can <a href="/login/sing_up">sign up</a> with a valid email account. 
Your email account will not be visible anywhere on this site, so signing up here won\'t cause unwanted messages (spam).
</p>
<p>The purpose of this site is to exchange information, views, opinions on the process descriptions published here. Please avoid personal attacks, slurs, and profanity in your interactions.
Please make sure that your postings in are relevant to the subject at hand. 
It is normal for some topics to drift from the stated subject. 
However, to ensure maximum benefit for everyone, 
we encourage you to keep your postings as close to the subject as possible.
Please keep in mind that this is a public space, so don\'t post anything that you don\'t want the world to see. 
            </p><p></p>')
AdminMessage.create(:guid => 'Login', :text => '<h3>Welcome to EPF Wiki</h3><br>
                            Software process descriptions that anyone can edit.<br>')
AdminMessage.create(:guid => 'Help', :text => '')
AdminMessage.create(:guid => 'Terms of Use', :text => '<p>15th November, 2004</p> 

    <p><strong>Terms and Conditions of Use for the  EPF Wiki Web Site</strong></p>

    <p>These terms of use are based on <a href="http://www.eclipse.org/legal/termsofuse.php" target="_new">Eclipse.org Terms of Use</a></p><p>BY ACCESSING, BROWSING OR USING THIS WEB SITE, YOU
    ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTAND AND AGREE TO BE BOUND BY THESE TERMS
    AND CONDITIONS.</p>

    <p>This Web site is a service made available by the Eclipse Foundation. 
    All software, documentation, information and/or other materials provided on and through this Web site
    ("Content") may be used solely under the following terms and conditions ("Terms of Use").</p>

    <p>This Web site may contain other proprietary notices and copyright information, the terms of which must
    be observed and followed.  The Content on this Web site may contain technical inaccuracies or typographical
    errors and may be changed or updated without notice. The Eclipse Foundation may also make improvements
    and/or changes to the Content at any time without notice.</p>

    <p>The Eclipse Foundation, its members ("Members") assume no responsibility regarding the
    accuracy of the Content and use of the Content is at the recipient\'s  The Eclipse Foundation and
    the Members provide no assurances that any reported problems with any Content will be resolved.
    Except as otherwise expressly stated, by providing the Content, neither the Eclipse Foundation or the Members
    grant any licenses to any copyrights, patents or any other intellectual property rights.</p>

    <p>The Eclipse Foundation and the Members do not want to receive confidential information from you
    through this Web site.  Please note that any information or material sent to The Eclipse Foundation or the Members
    will be deemed NOT to be confidential.</p>

    <p>You are prohibited from posting or transmitting to or from this Web site any unlawful, threatening, libelous,
    defamatory, obscene, scandalous, inflammatory, pornographic, or profane material, or any other material that
    could give rise to any civil or criminal liability under the law.</p>

    <p>The Eclipse Foundation and the Members make no representations whatsoever about any other
    Web site that you may access through this Web site. When you access a non-Eclipse Foundation Web site,
    even one that may contain the organization\'s name or mark, please understand that it is independent from
    The Eclipse Foundation, and that the the Eclipse Foundation and the Members have no control over
    the content on such Web site. In addition, a link to a non-Eclipse Foundation Web site does not mean that
    the Eclipse Foundation or the Members endorse or accept any responsibility for the content, or the use,
    of such Web site. It is up to you to take precautions to ensure that whatever you select for your use is free of such
    items as viruses, worms, Trojan horses and other items of a destructive nature.  </p>

    <p>IN NO EVENT WILL THE ECLIPSE FOUNDATION AND/OR THE MEMBERS BE LIABLE TO YOU
    (AN INDIVIDUAL OR ENTITY) OR ANY OTHER INDIVIDUAL OR ENTITY FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    PUNITIVE, SPECIAL OR CONSEQUENTIAL DAMAGES RELATED TO ANY USE OF THIS WEB SITE, THE CONTENT,
    OR ON ANY OTHER HYPER LINKED WEB SITE, INCLUDING, WITHOUT LIMITATION, ANY LOST PROFITS, LOST SALES,
    LOST REVENUE, LOSS OF GOODWILL, BUSINESS INTERRUPTION, LOSS OF PROGRAMS OR OTHER DATA ON
    YOUR INFORMATION HANDLING SYSTEM OR OTHERWISE, EVEN IF THE ECLIPSE FOUNDATION OR THE MEMBERS
    ARE EXPRESSLY ADVISED OR AWARE OF THE POSSIBILITY OF SUCH DAMAGES OR LOSSES.</p>

    <p>ALL CONTENT IS PROVIDED BY THE ECLIPSE FOUNDATION AND/OR THE MEMBERS ON AN
    "AS IS" BASIS ONLY.  THE ECLIPSE FOUNDATION AND THE MEMBERS PROVIDE NO REPRESENTATIONS,
    CONDITIONS AND/OR WARRANTIES, EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
    WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY AND NONINFRINGEMENT.</p>

    <p>The Eclipse Foundation and the Members reserve the right to investigate complaints or reported
    violations of these Terms of Use and to take any action they deem appropriate including, without limitation,
    reporting any suspected unlawful activity to law enforcement officials, regulators, or other third parties and
    disclosing any information necessary or appropriate to such persons or entities relating to user profiles,
    e-mail addresses, usage history, posted materials, IP addresses and traffic information.</p>

    <p>The Eclipse Foundation and the Members reserve the right to seek all remedies available at law
    and in equity for violations of these Terms of Use, including but not limited to the right to block access from
    a particular Internet address to this Web site.</p>

    <p><strong>Licenses</strong></p>

    <p>The Content provided on this Web site is provided under the terms and conditions of the
    <a href="http://www.eclipse.org/legal/epl/notice.php" target="_new">Eclipse Foundation Software User Agreement</a> and
    those additional terms, conditions and notices referenced therein.</p>

    <p>If the Content is licensed to you under the terms and conditions of the <a href="http://www-128.ibm.com/developerworks/library/os-cpl.html" target="_blank">Common Public License </a>("CPL")
    or the <a href="http://www.eclipse.org/legal/../org/documents/epl-v10.php" target="_new">Eclipse Public License</a> ("EPL"), any Contributions, as defined in the
    applicable license(s), uploaded, submitted, or otherwise made available to the Eclipse Foundation and/or the Members,
    by you that relate to such Content are provided under the terms and conditions of both the CPL and the EPL and can be made
    available to others under the terms of the CPL and/or the EPL.</p>

  
    <p>If the Content is licensed to you under license terms and conditions other than the CPL or the EPL
    ("Other License"), any modifications, enhancements and/or other code and/or documentation
    ("Modifications") uploaded, submitted, or otherwise made available to the Eclipse Foundation and/or the
    Members, by you that relate to such Content are provided under terms and conditions of the
    Other License and can be made available to others under the terms of the Other License. In addition, with regard
    to Modifications for which you are the copyright holder, you are also providing the Modifications under the terms
    and conditions of both the CPL and the EPL and such Modifications can be made available to others under the
    terms of the CPL and/or the EPL.</p>

    <p>For all other software, information and other material including, without limitation, ideas, concepts, know-how
    and techniques, uploaded, submitted or otherwise made available to The Eclipse Foundation, the Members,
    and/or users of this Web-site, (collectively "Material"), you grant (or warrant that the
    owner of such rights has expressly granted) the Eclipse Foundation, the Members and the users of
    this Web-site a worldwide, unrestricted, royalty free, fully paid up, irrevocable, perpetual, non-exclusive license
    to use, make, reproduce, prepare derivative works of, publicly display, publicly perform, transmit, sell, distribute,
    sublicense or otherwise transfer such Materials, and/or derivative works thereof, and authorize third parties to do
    any, some or all of the foregoing including, but not limited to, sublicensing others to do any some or all of
    the foregoing indefinitely. You represent and warrant that to your knowledge, you have sufficient rights in the
    Materials to grant the foregoing rights and licenses.</p>

    <p>All logos and trademarks contained on this Web site are and remain the property of their respective owners.
    No licenses or other rights in or to such logos and/or trademarks are granted to you.</p>

    <p>You can learn more about the <a href="privacypolicy">EPF Wiki privacy practices</a> on the Web.</p>')
AdminMessage.create(:guid => 'Privacy Policy', :text => '<p>15th November, 2004</p> 

    <p><strong>Privacy</strong></p>
  
    <p>You can visit EPF Wiki without revealing who you are or
    any information about yourself. There are times, however, when the Eclipse Foundation or its Members
    ("We" or "Us") may need information from you.
    You may choose to give personal information, such as your name
    and address or e-mail id that may be needed, for example, to correspond with
    you. We intend to let you know how such information will be used before it is
    collected from you on the Internet. If
    you tell Us that you do not want Us to use this information as a basis for
    further contact with you, We will respect your wishes.</p>

    <p><strong>Information Security and Quality</strong></p>

    <p>We intend to protect the quality and integrity of your
    personally identifiable information. We
    have tried to implement appropriate technical and organizational measures, such
    as using encryption for transmission of certain forms of information, to help
    keep that information secure, accurate, current, and complete.</p>

    <p>We will make a sincere effort to respond in a timely manner
    to your requests to correct inaccuracies in your personal information. To
    correct inaccuracies in your personal information please return the message
    containing the inaccuracies to the sender with details of the correction
    requested.</p>

    <p><strong>Clickstream Data and Cookies</strong></p>

    <p>We sometimes collect anonymous information from visits to
    this Web site to help provide better service.
    For example, We keep track of the domains from which people visit and We
    also measure visitor activity on EPF Wiki, but in ways that keep the
    information anonymous. This anonymous
    information is sometimes known as "clickstream data." We may use this data to analyze trends and statistics and to help
    us tailor the Web site to better serve Eclipse participants.</p>
  
    <p>Also, when personal data is collected from you in connection
    with a transaction (such as contribution of code or posting to newsgroups) We
    may extract some information about that transaction in an anonymous format and
    combine it with other anonymous information such as clickstream data. This anonymous information is used and
    analyzed only at an aggregate level to help Us understand trends and patterns.</p>

    <p>Some EPF Wiki pages use cookies to better serve you when
    you return to the site. You can set
    your browser to notify you before you receive a cookie, giving you the chance
    to decide whether to accept it. You can
    also set your browser to turn off cookies.
    If you do so, however, some areas of some sites may not function
    properly.</p>

    <p>To the extent Contributions and other Material (as defined
    in the Terms of Use) contain personal information about you, including, but not
    limited to, you name, We have the right to provide that information to others
    pursuant to the Term of Use.</p>

    <p><strong>Business Relationships</strong></p>

    <p>This Web site contains links to other Web sites.We are not responsible for the privacy
    practices or the content of such Web sites.</p>

    <p><strong>Notification of Changes</strong></p>

    <p>This privacy statement was last updated on November 15, 2004.
    A notice will be posted on this Web site home page for thirty (30) days
    whenever this privacy statement is changed.</p>

    <p><strong>Questions Regarding This Statement</strong></p><p>This statement is based on <a href="http://www.eclipse.org/legal/privacy.php" target="_new">Eclipse.org Privacy Practices</a>.</p>

    <p>Questions regarding this statement should be directed to: <a href="mailto:license@eclipse.org">license@eclipse.org</a>.</p>
    ')

end

  def self.down
    AdminMessage.destroy_all
  end
end
