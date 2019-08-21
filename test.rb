require 'strip_tags'
require 'test/unit'

# Unit tests for testing the tag stripping functionality.

class TestCase < Test::Unit::TestCase

	def setup
		@ps3_stripper = StripTags.new(%w(PS3 CAN_COMPILE_PS3), %w(STRIPPED_PS3 STRIPPED_CAN_COMPILE_PS3))
	end
	
	def test_simple()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef PS3
	bla
#endif
END_INPUT
#ifdef STRIPPED_PS3
//	...
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_leave()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef KAKA
	bla
#endif
END_INPUT
#ifdef KAKA
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_indentation()
		input, output =  <<END_INPUT, <<END_OUTPUT
	#ifdef PS3
	bla
		#endif
END_INPUT
	#ifdef STRIPPED_PS3
//	...
		#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_nesting()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef DEV
	#ifdef PS3
		bla
	#endif
	#ifdef WIN32
		wa
	#endif
	#ifdef PS3
		#ifdef DEV
			stuff
		#endif
	#endif
#endif
END_INPUT
#ifdef DEV
	#ifdef STRIPPED_PS3
//		...
	#endif
	#ifdef WIN32
		wa
	#endif
	#ifdef STRIPPED_PS3
//		...... ...
//			.....
//		......
	#endif
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_else()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef PS3
	bla
#else
	blo
#endif
#ifdef WIN32
	bla
#else
	blo
#endif
END_INPUT
#ifdef STRIPPED_PS3
//	...
#else
	blo
#endif
#ifdef WIN32
	bla
#else
	blo
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_ifndef()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifndef PS3
	#ifndef WIN32
		bla
	#endif
#endif
END_INPUT
#ifndef STRIPPED_PS3
	#ifndef WIN32
		bla
	#endif
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_defined()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if   defined(PS3)
	bla
#endif
#if   defined(WIN32)
	bla
#endif
END_INPUT
#if   defined(STRIPPED_PS3)
//	...
#endif
#if   defined(WIN32)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_naked()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if PS3
	bla
#endif
#if WIN32
	bla
#endif
END_INPUT
#if STRIPPED_PS3
//	...
#endif
#if WIN32
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_not_defined()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if !defined(PS3)
	bla
#endif
#if !defined(WIN32)
	bla
#endif
END_INPUT
#if !defined(STRIPPED_PS3)
	bla
#endif
#if !defined(WIN32)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_or_clause()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(PS3) || defined(WIN32)
	bla
#endif
#if defined(PS3) || defined(PS3)
	bla
#endif
END_INPUT
#if defined(STRIPPED_PS3) || defined(WIN32)
	bla
#endif
#if defined(STRIPPED_PS3) || defined(STRIPPED_PS3)
//	...
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_and_clause()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(PS3) && defined(WIN32)
	bla
#endif
#if defined(DEV) && defined(WIN32)
	bla
#endif
END_INPUT
#if defined(STRIPPED_PS3) && defined(WIN32)
//	...
#endif
#if defined(DEV) && defined(WIN32)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def complicated_test()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if (defined(PS3) || defined(ANDROID)) && defined(WIN32)
	bla
#endif
END_INPUT
#if (defined(STRIPPED_PS3) || defined(ANDROID)) && defined(WIN32)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
#if !(defined(PS3))
	bla
#endif
END_INPUT
#if !(defined(PS3))
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_mismatched_ifs()
		input =  <<END_INPUT
#if STUFF
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
		input =  <<END_INPUT
#endif
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
		input =  <<END_INPUT
#else
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
	end
	
	def test_bad_comments()
		input =  <<END_INPUT
/* block comment #if STUFF
#endif
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
		input =  <<END_INPUT
#if STUFF */
#endif
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
	end
	
	def test_strings()
		input =  <<END_INPUT
"#if STUFF"
#endif
END_INPUT
		assert_raise(RuntimeError) {@ps3_stripper.filter(input)}
		input, output =  <<END_INPUT, <<END_OUTPUT
fprintf(out, "#ifdef PS3");
END_INPUT
fprintf(out, "#ifdef PS3");
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_ok_comments()
		input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef PS3 // test for PS3
	bla
#endif // PS3
END_INPUT
#ifdef STRIPPED_PS3 // test for STRIPPED_PS3
	bla
#endif // STRIPPED_PS3
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
// #ifdef PS3
	bla
// #endif
END_INPUT
// #ifdef PS3
	bla
// #endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
input, output =  <<END_INPUT, <<END_OUTPUT
#ifdef PS3 /* test for PS3 */
	bla
#endif /* PS3 */
END_INPUT
#ifdef STRIPPED_PS3 /* test for STRIPPED_PS3 */
	bla
#endif /* STRIPPED_PS3 */
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
/* #ifdef PS3 */
	bla
/* #endif */
END_INPUT
/* #ifdef PS3 */
	bla
/* #endif */
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
/*
	ok
*/
#ifdef PS3
	// ok
	/* ok */
#endif
/* ok */
END_INPUT
/*
	ok
*/
#ifdef STRIPPED_PS3
//	.. ..
//	.. .. ..
#endif
/* ok */
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
/* inside comment

#if PS3
	bla
#endif

*/
END_INPUT
/* inside comment

#if STRIPPED_PS3
//	...
#endif

*/
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_complicated_without_tag()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
	bla
#endif
END_INPUT
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_bad_in_comment()
		input, output =  <<END_INPUT, <<END_OUTPUT
/*
    using so many "#if"s.
*/
END_INPUT
/*
    using so many "#if"s.
*/
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
	
	def test_complicated()
		input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(PS3) || (defined(WIN32) && defined(CAN_COMPILE_PS3))
	bla
#endif
END_INPUT
#if defined(STRIPPED_PS3) || (defined(WIN32) && defined(STRIPPED_CAN_COMPILE_PS3))
//	...
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(_DEBUG) && !defined(PS3) && !defined(_XBOX) && !defined(ANDROID) && !(defined(_MSC_ER) && _MSC_VER >= 1600)
	bla
#endif
END_INPUT
#if defined(_DEBUG) && !defined(STRIPPED_PS3) && !defined(_XBOX) && !defined(ANDROID) && !(defined(_MSC_ER) && _MSC_VER >= 1600)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
#if defined(PS3) || defined (__APPLE__) || defined(ANDROID)
	bla
#endif
END_INPUT
#if defined(STRIPPED_PS3) || defined (__APPLE__) || defined(ANDROID)
	bla
#endif
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
		input, output =  <<END_INPUT, <<END_OUTPUT
Vector4 tmp = cd.materials[dominant_layer].densities; //* vector4(w,w,w,w);
END_INPUT
Vector4 tmp = cd.materials[dominant_layer].densities; //* vector4(w,w,w,w);
END_OUTPUT
		assert_equal(output, @ps3_stripper.filter(input))
	end
end