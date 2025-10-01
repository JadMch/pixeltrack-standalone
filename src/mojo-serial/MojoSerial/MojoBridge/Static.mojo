from memory.memory import _malloc
from sys import sizeof


@nonmaterializable(NoneType)
@deprecated(
    "This structure does not function correctly except in certain linear code"
    " sequences. Please refrain from using Static"
)
struct Static[T: Movable, id: Int = 0]:
    """This highly unsafe module allows you to use static variables within Mojo.
    You must ALWAYS use the init() function to initialize the backing the first time.
    Usage:
    ```mojo
    Static[Int].init()
    Static[Int].get() = 5
    # now Static[Int] (or alternatively, Static[Int, 0] is 5 everywhere in your program
    Static[Int].init()
    Static[Int, 3].get() = 23
    # now Static[Int, 3] is 23 everywhere in your program
    ```
    Note: May break as implementation of Mojo alias changes.
    """

    @staticmethod
    @always_inline("nodebug")
    fn __get_backing() -> UnsafePointer[UnsafePointer[T]]:
        """This function holds the actual object referenced in this static variable.
        """
        alias __storage = _malloc[UnsafePointer[T]](sizeof[UnsafePointer[T]]())
        return __storage

    @staticmethod
    @always_inline("nodebug")
    @deprecated(
        "This structure does not function correctly except in certain linear"
        " code sequences. Please refrain from using Static"
    )
    fn unsafe_ptr() -> UnsafePointer[T]:
        """Returns an unsafe pointer to the static object."""
        return Self.__get_backing()[]

    @staticmethod
    @always_inline("nodebug")
    @deprecated(
        "This structure does not function correctly except in certain linear"
        " code sequences. Please refrain from using Static"
    )
    fn get() -> ref [MutableOrigin.cast_from[StaticConstantOrigin]] T:
        """Returns a mutable reference to the static object."""
        return Self.__get_backing()[][]

    @staticmethod
    @always_inline("nodebug")
    @deprecated(
        "This structure does not function correctly except in certain linear"
        " code sequences. Please refrain from using Static"
    )
    fn init(var item: T):
        """Initializes the static object with a value. This function must ALWAYS be called before attempting to use the static object.
        """
        Self.__get_backing().init_pointee_move(UnsafePointer[T].alloc(1))
        Self.__get_backing()[].init_pointee_move(item^)
