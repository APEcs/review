<?php
/**
 * Popup tage processing extension.
 *
 * To activate this extension, add the following into your LocalSettings.php file:
 * require_once('$IP/extensions/TWPopup/twpopup.php');
 *
 * @ingroup Extensions
 * @author Chris Page
 * @version 1.0
 * @link 
 * @license http://www.gnu.org/copyleft/gpl.html GNU General Public License 2.0 or later
 */
 
/**
 * Protect against register_globals vulnerabilities.
 * This line must be present before any global variable is referenced.
 */
if( !defined( 'MEDIAWIKI' ) ) {
	echo( "This is an extension to the MediaWiki package and cannot be run standalone.\n" );
	die( -1 );
}

 
/** MooTools control flag. Set this to false to stop mootools loading (in case another extension
 *  has loaded mootools already
 */
$eLoadMooTools = true;


// Extension credits that will show up on Special:Version    
$wgExtensionCredits['parserhook'][] = array(
    'path'         => __FILE__,
	'name'         => 'Popups',
	'version'      => '0.3.0',
	'author'       => 'Chris Page', 
	'url'          => '',
	'description'  => 'This extension provides the <nowiki><popup></nowiki> tag'
);

$wgHooks['ParserFirstCallInit'][] = 'efPopupSetup';
$wgHooks['ParserBeforeTidy'][] = 'efEncodeBodies';
 
function efPopupSetup(&$parser) {
    global $wgOut;
    global $wgScriptPath;
    global $eLoadMooTools;

    // Generate the content required to load the javascript and stylesheet
    $output = '';
    if($eLoadMooTools) $output .= "<script type=\"text/javascript\" src=\"$wgScriptPath/extensions/TWPopup/mootools-core.js\"><!-- mootools js --></script>\n\t\t";
    $output .= "<script type=\"text/javascript\" src=\"$wgScriptPath/extensions/TWPopup/popup.js\"><!-- popup js --></script>\n<script type=\"text/javascript\" src=\"$wgScriptPath/extensions/TWPopup/webtoolkit.base64.js\"><!-- popup js --></script>\n\t\t<link href=\"$wgScriptPath/extensions/TWPopup/popup.css\" rel=\"stylesheet\" type=\"text/css\" />\n";

    $wgOut -> addScript($output);
    $parser -> setHook("popup", "renderPopup");

    return true;
}


function renderPopup($input, $argv, $parser, $frame = 0) 
{
    global $wgVersion;
    global $wgTitle;

    // Grab and convert arguments set for the tag...
    $hottext = isset($argv['title']) ? htmlspecialchars($argv['title']) : 'popup';
    $xoffset = isset($argv['xoff'])  ? intval($argv['xoff']) : NULL;
    $yoffset = isset($argv['yoff'])  ? intval($argv['yoff']) : NULL;
    $hdelay  = isset($argv['hide'])  ? intval($argv['hide']) : NULL;
    $sdelay  = isset($argv['show'])  ? intval($argv['show']) : NULL;

    $output = '';
    $title  = '';

    // If we have any input, create the popup tags...
    if($input != '') {
        // Build arguments to shove into the div title as needed.
        if(isset($xoffset)) $title .= "xoff=$xoffset;";
        if(isset($yoffset)) $title .= "yoff=$yoffset;";
        if(isset($hdelay))  $title .= "hide=$hdelay;";
        if(isset($sdelay))  $title .= "show=$sdelay;";

        // And generate the popup elements
        $output .= '<span class="twpopup">'. $parser -> unstrip($parser -> recursiveTagParse($hottext), $parser -> mStripState);
        $output .= '<span class="twpopup-inner"';
        if($title != '') $output .= " title=\"$title\""; // Don't bother to include the title if there's no args set.

        // Commented code here is the alternative parser technique, note that while this works
        // fine in most situations, it will break hilariously with extensions that do multi-stage
        // parsing (like Cite). At present there is no clear indication that this method will
        // produce better results than the primary parsing system shown below.
        //$myParser = new Parser();
        //$myParserOptions = new ParserOptions();
        //$myParserOptions->initialiseFromUser($wgUser);
        //$content = $myParser->parse($input, $wgTitle, $myParserOptions);
        //$output .= '>' . base64_encode($content -> getText()) . "</span></span>";

        // Parse the content of the popup, and place it into the page surrounded by appropriate markers.
        $content = $parser -> unstrip($parser -> recursiveTagParse($input, $frame), $parser -> mStripState);
        $output .= '>TWPOPIN' . $content . "TWPOPOUT</span></span>";
    }

    return $output;
}

/** Convert the contents of a matched popup body to base64 encoded data.
 *  This takes matches found in efEncodeBodies() and generates the 
 *  equivalent encoded as base64 (to avoid html validation problems)
 */
function encodeContent($matches)
{
    return ">".base64_encode($matches[1])."</span>";
}

/** Convert all popup bodies to base64 encoded data. This is called as
 *  the hook function for ParserBeforeTidy so that it can safely encode
 *  any body contents before the tidy comes along and breaks the page.
 *
 *  @note As the contents of popups are encoded before tidy is done,
 *        it is possible that the contents may need to be tidied but
 *        actually aren't. This may need to be addressed in future.
 */
function efEncodeBodies( &$parser, &$text ) 
{
    $text = preg_replace_callback('|>TWPOPIN(.+?)TWPOPOUT</span>|s', "encodeContent", $text);

    return true;
}
