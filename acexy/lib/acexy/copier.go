package acexy

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log/slog"
	"time"
)

// Copier is an implementation that copies the data from the source to the destination.
// It has an empty timeout that is used to determine when the source is empty - this is,
// it has no more data to read after the timeout.
type Copier struct {
	// The destination to copy the data to.
	Destination io.Writer
	// The source to copy the data from.
	Source io.Reader
	// The timeout to use when the source is empty.
	EmptyTimeout time.Duration
	// The buffer size to use when copying the data.
	BufferSize int
	// Context for cancellation.
	Context context.Context

	/**! Private Data */
	timer          *time.Timer
	bufferedWriter *bufio.Writer
}

// Starts copying the data from the source to the destination.
func (c *Copier) Copy() error {
	c.bufferedWriter = bufio.NewWriterSize(c.Destination, c.BufferSize)
	c.timer = time.NewTimer(c.EmptyTimeout)
	defer func() {
		c.bufferedWriter.Flush()
		if !c.timer.Stop() {
			<-c.timer.C // Drain the timer channel
		}
	}()

	done := make(chan struct{})
	defer close(done)

	go func() {
		select {
		case <-done:
			slog.Debug("Done copying", "source", c.Source, "destination", c.Destination)
			return
		case <-c.Context.Done():
			slog.Warn("Copy canceled", "error", c.Context.Err())
			c.bufferedWriter.Flush()
			if closer, ok := c.Source.(io.Closer); ok {
				closer.Close()
			}
			if closer, ok := c.Destination.(io.Closer); ok {
				closer.Close()
			}
			return
		case <-c.timer.C:
			slog.Warn("Copy timeout reached", "source", c.Source, "destination", c.Destination)
			c.bufferedWriter.Flush()
			if closer, ok := c.Source.(io.Closer); ok {
				closer.Close()
			}
			if closer, ok := c.Destination.(io.Closer); ok {
				closer.Close()
			}
			return
		}
	}()

	_, err := io.Copy(c, c.Source)
	if err != nil {
		slog.Error("Error during copy", "error", err)
		return fmt.Errorf("copy failed: %w", err)
	}
	return nil
}

// Write writes the data to the destination. It also resets the timer if there is data to write.
func (c *Copier) Write(p []byte) (n int, err error) {
	if len(p) == 0 {
		return 0, nil
	}
	if c.timer == nil || c.bufferedWriter == nil {
		return 0, io.ErrClosedPipe
	}
	// Reset the timer, since we have data to write
	c.timer.Reset(c.EmptyTimeout)
	// Write the data to the destination
	return c.bufferedWriter.Write(p)
}
