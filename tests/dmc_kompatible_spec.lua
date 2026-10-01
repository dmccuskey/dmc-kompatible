--====================================================================--
-- tests/dmc_kompatible_spec.lua
--
-- Unit tests for dmc-kompatible, using Luna Test.
-- Run with tests/run_unit.sh
--
-- Solar2D's display and native are stand-ins here: their objects
-- record what their color methods are called with
--====================================================================--


module(..., package.seeall)



--====================================================================--
--== Setup


local MODULE = 'dmc_corona.dmc_kompatible'

local cfgFile = 'dmc_corona.cfg'

-- stand-ins for the Solar2D globals the module uses
package.preload.json = function() return require 'dkjson' end

_G.system = {
	ResourceDirectory=newproxy(),
	pathForFile=function( name ) return './'..cfgFile end,
}

-- newObject()
-- a display object whose methods record their arguments in calls;
-- lines and native objects have no setFillColor, as in Solar2D
--
local function newObject( methods )
	return function( ... )
		local o = { args={ ... }, calls={}, anchorX=0.5, anchorY=0.5 }
		for _, name in ipairs( methods ) do
			o[ name ] = function( self, ... )
				o.calls[ #o.calls+1 ] = { name=name, self=self, n=select( '#', ... ), ... }
			end
		end
		return o
	end
end

local SHAPE = newObject{ 'setFillColor', 'setStrokeColor' }
local SOLAR2D_CENTER = newproxy()

_G.display = {
	contentWidth=320,
	CenterReferencePoint=SOLAR2D_CENTER,
	TopLeftReferencePoint=newproxy(),
	newImage=function( name, ... )
		if name == 'missing.png' then return nil end
		return SHAPE( name, ... )
	end,
	-- Solar2D ignores setting a line's color methods the usual way
	newLine=function( ... )
		local o = newObject{ 'setStrokeColor' }( ... )
		local own = { setStrokeColor=o.setStrokeColor, setColor=o.setStrokeColor }
		o.setStrokeColor = nil
		return setmetatable( o, {
			__index=own,
			__newindex=function( t, k, v ) if not own[ k ] then rawset( t, k, v ) end end,
		} )
	end,
	newGroup=newObject{},
	newContainer=newObject{},
	newSprite=newObject{},
}
for _, name in ipairs{ 'newCircle', 'newPolygon', 'newRect',
	'newRoundedRect', 'newText' } do
	display[ name ] = SHAPE
end
display.newImageRect = display.newImage

_G.native = {
	systemFont='system',
	newTextBox=newObject{ 'setTextColor' },
	newTextField=newObject{ 'setTextColor' },
	newWebView=newObject{},
}

-- load()
-- a fresh copy of the module, with this [DMC_KOMPATIBLE] config;
-- nil for no config at all: the boot loader reads cfgFile
--
local function load( config )
	package.loaded[ MODULE ] = nil
	package.loaded[ 'dmc_corona_boot' ] = nil
	_G.__dmc_corona = nil
	if config then
		_G.__dmc_corona = { dmc_corona={}, dmc_kompatible=config }
	end
	return require( MODULE )
end

-- lastCall()
-- the last color call on o, as { name, values... }
--
local function lastCall( o )
	return o.calls[ #o.calls ]
end

-- assert_color()
-- the values, to 3 places
--
local function assert_color( expected, call )
	assert_equal( #expected, call.n )
	for i, v in ipairs( expected ) do
		assert_true( math.abs( v - call[i] ) < 0.001,
			'value '..i..': '..tostring( call[i] )..', expected '..v )
	end
end

local function assert_error_match( pattern, f )
	local ok, err = pcall( f )
	assert_false( ok )
	assert_match( pattern, err )
end

-- capturePrint()
-- what f prints, a line per call
--
local function capturePrint( f )
	local lines, print_ = {}, _G.print
	_G.print = function( ... ) lines[ #lines+1 ] = table.concat( { ... }, ' ' ) end
	local ok, err = pcall( f )
	_G.print = print_
	assert( ok, err )
	return lines
end



--====================================================================--
--== Tests


function test_module()
	local Kompatible = load( {} )
	assert_equal( '1.2.0', Kompatible.VERSION )
	local d, n = Kompatible()
	assert_equal( 'DMC_KOMPATIBLE DISPLAY', d.NAME )
	assert_equal( 'DMC_KOMPATIBLE NATIVE', n.NAME )
	assert_equal( d, Kompatible.display )
	assert_equal( n, Kompatible.native )
	-- the rest falls through to Solar2D's
	assert_equal( 320, d.contentWidth )
	assert_equal( 'system', n.systemFont )
end

function test_no_globals()
	-- leaked by an earlier load of master's
	for _, name in ipairs{ '_extend', 'createClosure', 't', 'translateRGBToHDR',
		'addSetAnchor', 'addSetFillColor', 'addSetStrokeColor', 'Display', 'Native' } do
		rawset( _G, name, nil )
	end
	local before = {}
	for k in pairs( _G ) do before[ k ] = true end
	local d = load( {} )()
	local o = d.newRect( 0, 0, 10, 10 )
	o:setReferencePoint( d.TopLeftReferencePoint )
	o:setFillColor{ type='gradient', color1={ 0, 0, 0 }, color2={ 1, 1, 1 } }
	o:setStrokeColor( 1, 2, 3 )
	for k in pairs( _G ) do
		if not before[ k ] and k ~= '__dmc_corona' then
			fail( 'new global: '..tostring( k ) )
		end
	end
	assert_equal( display, _G.display )
end

function test_colors()
	local d = load( {} )()
	local o = d.newRect()
	o:setFillColor( 255, 0, 51 )
	assert_color( { 1, 0, 0.2, 1 }, lastCall( o ) )
	assert_equal( o, lastCall( o ).self )
	-- alpha 0-255, as in Graphics 1.0
	o:setFillColor( 255, 0, 51, 51 )
	assert_color( { 1, 0, 0.2, 0.2 }, lastCall( o ) )
	o:setFillColor( 51 )
	assert_color( { 0.2, 0.2, 0.2, 1 }, lastCall( o ) )
	o:setStrokeColor( '#FF3300' )
	assert_equal( 'setStrokeColor', lastCall( o ).name )
	assert_color( { 1, 0.2, 0 }, lastCall( o ) )
end

-- the gray became the alpha: ( 51, 102 ) gave a gray of 51, 102, 102
function test_gray_with_alpha()
	local d = load( {} )()
	local o = d.newCircle()
	o:setFillColor( 51, 102 )
	assert_color( { 0.2, 0.2, 0.2, 0.4 }, lastCall( o ) )
end

-- the table was translated in place, so its second use was near black;
-- the alphas weren't translated
function test_gradient_copied()
	local d = load( {} )()
	local o = d.newRect()
	local g = { type='gradient', color1={ 255, 0, 0 }, color2={ 0, 0, 255, 51 }, direction='right' }
	o:setFillColor( g )
	o:setFillColor( g )
	local paint = lastCall( o )[1]
	assert_equal( 'right', paint.direction )
	assert_color( { 1, 0, 0, 1 }, { n=4, unpack( paint.color1 ) } )
	assert_color( { 0, 0, 1, 0.2 }, { n=4, unpack( paint.color2 ) } )
	assert_equal( 255, g.color1[1] )
end

function test_other_paints()
	local d = load( {} )()
	local o = d.newRect()
	local paint = { type='image', filename='a.png' }
	o:setFillColor( paint )
	assert_equal( paint, lastCall( o )[1] )
end

-- a name printed "ERROR dmc_kolor" and gave white; other mistakes
-- printed or raised inside the module
function test_bad_colors()
	local d = load( {} )()
	local o = d.newRect()
	assert_error_match( "dmc_kompatible: invalid color 'red'.*dmc%-kolor", function() o:setFillColor( 'red' ) end )
	assert_error_match( "invalid color '#FFF'", function() o:setFillColor( '#FFF' ) end )
	assert_error_match( 'invalid color type nil', function() o:setFillColor() end )
	assert_error_match( 'argument 2 is a string', function() o:setStrokeColor( 1, '2', 3 ) end )
	assert_error_match( '5 numbers', function() o:setFillColor( 1, 2, 3, 4, 5 ) end )
	assert_error_match( 'gradient color2', function()
		o:setFillColor{ type='gradient', color1={ 1, 2, 3 } }
	end )
	assert_equal( 0, #o.calls )
end

-- the error is reported at the caller's line
function test_error_level()
	local d = load( {} )()
	local o = d.newRect()
	local ok, err = pcall( function() o:setFillColor( 'red' ) end )
	assert_match( '^[^:]*dmc_kompatible_spec.lua:%d+: dmc_kompatible', err )
end

-- each constructor sets its Graphics 1.0 reference point
function test_initial_reference_points()
	local d, n = load( {} )()
	for _, name in ipairs{ 'newCircle', 'newRect', 'newRoundedRect', 'newText' } do
		local o = d[ name ]()
		assert_equal( 0.5, o.anchorX, name ) ; assert_equal( 0.5, o.anchorY, name )
	end
	for _, o in ipairs{ d.newImage( 'a.png' ), d.newImageRect( 'a.png', 1, 1 ),
		d.newLine(), d.newPolygon(), n.newTextField(), n.newTextBox(), n.newWebView() } do
		assert_equal( 0, o.anchorX ) ; assert_equal( 0, o.anchorY )
	end
	local g = d.newGroup()
	assert_equal( 0.5, g.anchorX )
	assert_equal( 'function', type( g.setReferencePoint ) )
end

function test_set_reference_point()
	local d = load( {} )()
	local o = d.newText()
	o:setReferencePoint( d.BottomRightReferencePoint )
	assert_equal( 1, o.anchorX ) ; assert_equal( 1, o.anchorY )
	o:setReferencePoint( d.TopCenterReferencePoint )
	assert_equal( 0.5, o.anchorX ) ; assert_equal( 0, o.anchorY )
	o:setReferencePoint( 0.25, 0.75 )
	assert_equal( 0.25, o.anchorX ) ; assert_equal( 0.75, o.anchorY )
	-- a missing value keeps the current one; it set nil
	o:setReferencePoint( 1 )
	assert_equal( 1, o.anchorX ) ; assert_equal( 0.75, o.anchorY )
	o:setReferencePoint( nil, 0 )
	assert_equal( 1, o.anchorX ) ; assert_equal( 0, o.anchorY )
end

-- Solar2D's own constants were ignored; nil and anything else set nil
function test_solar2d_and_bad_reference_points()
	local d = load( {} )()
	local o = d.newRect()
	o:setReferencePoint( display.TopLeftReferencePoint )
	assert_equal( 0, o.anchorX ) ; assert_equal( 0, o.anchorY )
	o:setReferencePoint( SOLAR2D_CENTER )
	assert_equal( 0.5, o.anchorX ) ; assert_equal( 0.5, o.anchorY )
	assert_error_match( 'takes a reference point.*got nil', function() o:setReferencePoint( d.Nowhere ) end )
	assert_error_match( 'takes a reference point', function() o:setReferencePoint( 'top' ) end )
	assert_error_match( 'takes a reference point', function() o:setReferencePoint{ 'a', 'b' } end )
	assert_equal( 0.5, o.anchorX )
end

-- line:setColor() and native setFillColor() called a missing method;
-- newPolygon kept Solar2D's 0-1 setFillColor
function test_methods_per_object()
	local d, n = load( {} )()
	local line = d.newLine()
	line:setColor( 255, 0, 0 )
	assert_equal( 'setStrokeColor', lastCall( line ).name )
	assert_color( { 1, 0, 0, 1 }, lastCall( line ) )
	line:setStrokeColor( 0, 255, 0 )
	assert_color( { 0, 1, 0, 1 }, lastCall( line ) )
	assert_nil( line.setFillColor )

	local poly = d.newPolygon()
	poly:setFillColor( 255, 0, 0 )
	assert_color( { 1, 0, 0, 1 }, lastCall( poly ) )

	local text = d.newText()
	text:setTextColor( 0, 0, 255 )
	assert_equal( 'setFillColor', lastCall( text ).name )
	assert_color( { 0, 0, 1, 1 }, lastCall( text ) )
	-- once, whichever was added first
	text:setFillColor( 255 )
	assert_color( { 1, 1, 1, 1 }, lastCall( text ) )

	local field, box, web = n.newTextField(), n.newTextBox(), n.newWebView()
	field:setTextColor( 255, 0, 0 )
	assert_equal( 'setTextColor', lastCall( field ).name )
	assert_color( { 1, 0, 0, 1 }, lastCall( field ) )
	box:setTextColor( '#00FF00' )
	assert_color( { 0, 1, 0 }, lastCall( box ) )
	assert_nil( field.setFillColor )
	assert_nil( web._setFillColor )
	assert_nil( web._setTextColor )

	assert_nil( n.newText ) -- Solar2D has none
end

-- newImage() and newImageRect() raised "attempt to index nil"
function test_missing_image()
	local d = load( {} )()
	assert_nil( d.newImage( 'missing.png' ) )
	assert_nil( d.newImageRect( 'missing.png', 10, 10 ) )
	assert_equal( 'function', type( d.newImage( 'a.png' ).setReferencePoint ) )
end

-- it was printed for every line, between blank lines
function test_line_warning_once()
	local d = load( {} )()
	local lines = capturePrint( function() d.newLine() ; d.newLine() end )
	assert_equal( 1, #lines )
	assert_match( "WARNING dmc_kompatible: .*strokeWidth", lines[1] )
	d = load( { print_warnings=false } )()
	assert_equal( 0, #capturePrint( function() d.newLine() end ) )
end

function test_activate_off()
	local d = load( { activate_reference=false, activate_fillcolor=false,
		activate_strokecolor=false } )()
	local o = d.newRect()
	assert_nil( o.setReferencePoint )
	assert_equal( 0.5, o.anchorX )
	assert_nil( o._setFillColor )
	assert_nil( o._setStrokeColor )
	assert_nil( d.newLine()._setStrokeColor )
	assert_nil( d.newImage( 'a.png' ).setReferencePoint )
end

-- without :BOOL, 'false' was a string, which counts as on
function test_config_strings()
	local d = load( { activate_reference='false', make_global='false' } )()
	assert_nil( d.newRect().setReferencePoint )
	assert_nil( _G.display.NAME )
end

function test_make_global()
	local solar2d_display, solar2d_native = _G.display, _G.native
	local d, n = load( { make_global=true } )()
	local ok_d, ok_n = _G.display == d, _G.native == n
	_G.display, _G.native = solar2d_display, solar2d_native
	assert_true( ok_d )
	assert_true( ok_n )
end

-- the config from the file, through the boot loader
function test_config_types()
	cfgFile = 'tests/typed.cfg'
	local d = load( nil )()
	cfgFile = 'dmc_corona.cfg'
	local o = d.newRect()
	assert_nil( o.setReferencePoint )
	assert_nil( o._setStrokeColor )
	assert_not_nil( o._setFillColor )
end
